defmodule Mix.Tasks.Gallformers.UpdateProdDb do
  @moduledoc """
  Updates the production database on Fly.io safely.

  This task:
  1. Validates and prepares local database (VACUUM + WAL checkpoint)
  2. Stops the production machine
  3. Restarts machine in sleep mode (releases DB lock)
  4. Backs up existing database (timestamped, can rollback)
  5. Uploads new database
  6. Verifies remote database integrity and data
  7. Clears Litestream backups (forces fresh generation)
  8. Restarts the app normally (health endpoint confirms success)

  ## Usage

      mix gallformers.update_prod_db path/to/gallformers.sqlite

  ## Prerequisites

  - flyctl CLI installed and authenticated
  - aws CLI installed and configured
  - jq installed
  - SQLite3 installed

  ## Example

      mix gallformers.update_prod_db priv/gallformers-v2.sqlite

  """

  use Mix.Task
  require Logger

  @requirements ["app.config"]

  # Configuration
  @app_name "gallformers"
  @db_path "/data/gallformers.sqlite"
  @min_species_count 5000

  # ANSI colors
  @red IO.ANSI.red()
  @green IO.ANSI.green()
  @yellow IO.ANSI.yellow()
  @blue IO.ANSI.blue()
  @reset IO.ANSI.reset()

  @impl Mix.Task
  def run(args) do
    case args do
      [local_db_path] ->
        execute(local_db_path)

      _ ->
        Mix.Shell.IO.error("Usage: mix gallformers.update_prod_db path/to/gallformers.sqlite")
        exit({:shutdown, 1})
    end
  end

  defp execute(local_db_path) do
    with :ok <- check_prerequisites(),
         :ok <- verify_local_file(local_db_path),
         {:ok, species_count} <- validate_local_db(local_db_path),
         {:ok, clean_db_path, checksum} <- create_clean_copy(local_db_path, species_count),
         :ok <- confirm_replacement(species_count, clean_db_path),
         {:ok, machine_id, machine_state} <- get_machine_info(),
         :ok <- stop_machine(machine_id, machine_state),
         :ok <- update_to_sleep_mode(machine_id),
         :ok <- start_sleeping_machine(machine_id),
         {:ok, backup_file} <- backup_existing_db(machine_id),
         :ok <- upload_database(machine_id, clean_db_path, backup_file),
         :ok <- verify_remote_db(machine_id, species_count, backup_file),
         :ok <- clear_litestream_backups(),
         :ok <- restore_normal_operation(machine_id) do
      print_success_summary(species_count, clean_db_path, checksum, backup_file)
      cleanup_temp_file(clean_db_path)
    else
      {:error, :user_cancelled} ->
        Mix.Shell.IO.info("Operation cancelled by user.")
        exit({:shutdown, 0})

      {:error, reason, context} ->
        Mix.Shell.IO.error("#{@red}Error: #{reason}#{@reset}")
        handle_error_recovery(context)
        exit({:shutdown, 1})

      {:error, reason} ->
        Mix.Shell.IO.error("#{@red}Error: #{reason}#{@reset}")
        exit({:shutdown, 1})
    end
  end

  ## Step 1: Check Prerequisites

  defp check_prerequisites do
    Mix.Shell.IO.info("#{@blue}Checking prerequisites...#{@reset}")

    required_commands = [
      {"flyctl", "fly"},
      {"sqlite3", "sqlite3"},
      {"jq", "jq"},
      {"aws", "aws"}
    ]

    missing =
      Enum.filter(required_commands, fn {name, cmd} ->
        case System.cmd("which", [cmd], stderr_to_stdout: true) do
          {_, 0} -> false
          _ -> name
        end
      end)

    if missing != [] do
      {:error, "Missing required dependencies: #{Enum.join(missing, ", ")}"}
    else
      # Check flyctl auth
      case System.cmd("fly", ["auth", "whoami"], stderr_to_stdout: true) do
        {_, 0} ->
          Mix.Shell.IO.info("#{@green}✓ All prerequisites met#{@reset}\n")
          :ok

        _ ->
          {:error, "Not authenticated with Fly.io. Run: fly auth login"}
      end
    end
  end

  ## Step 2: Verify Local File

  defp verify_local_file(path) do
    if File.exists?(path) do
      :ok
    else
      {:error, "Database file not found: #{path}"}
    end
  end

  ## Step 3: Validate Local Database

  defp validate_local_db(path) do
    Mix.Shell.IO.info("#{@blue}=== Step 1: Local Validation & Preparation ===#{@reset}")

    # Check integrity
    Mix.Shell.IO.info("Checking source database integrity...")

    case run_sqlite(path, "PRAGMA integrity_check;") do
      {:ok, "ok\n"} ->
        Mix.Shell.IO.info("#{@green}✓ Source integrity check passed#{@reset}")

      {:ok, result} ->
        {:error, "Source database failed integrity check: #{result}"}

      {:error, reason} ->
        {:error, "Failed to check integrity: #{reason}"}
    end
    |> case do
      :ok ->
        # Check species count
        Mix.Shell.IO.info("Checking species count...")

        case run_sqlite(path, "SELECT COUNT(*) FROM species;") do
          {:ok, count_str} ->
            count = String.trim(count_str) |> String.to_integer()
            Mix.Shell.IO.info("Species count: #{count}")

            if count >= @min_species_count do
              Mix.Shell.IO.info("#{@green}✓ Species count validated#{@reset}\n")
              {:ok, count}
            else
              {:error, "Species count (#{count}) is below minimum (#{@min_species_count})"}
            end

          {:error, reason} ->
            {:error, "Failed to count species: #{reason}"}
        end

      error ->
        error
    end
  end

  ## Step 4: Create Clean Copy

  defp create_clean_copy(source_path, species_count) do
    Mix.Shell.IO.info("Creating clean copy (VACUUM + WAL checkpoint)...")

    # Create temp directory
    temp_dir = System.tmp_dir!() |> Path.join("gallformers-#{:os.system_time(:second)}")
    File.mkdir_p!(temp_dir)

    clean_path = Path.join(temp_dir, "gallformers-clean.sqlite")

    # Copy source
    File.cp!(source_path, clean_path)

    # Run VACUUM and checkpoint
    case run_sqlite(clean_path, "PRAGMA wal_checkpoint(TRUNCATE); VACUUM;") do
      {:ok, _} ->
        Mix.Shell.IO.info("#{@green}✓ Clean database created#{@reset}")

        # Verify clean copy
        Mix.Shell.IO.info("Verifying clean copy...")

        with {:ok, "ok\n"} <- run_sqlite(clean_path, "PRAGMA integrity_check;"),
             {:ok, count_str} <- run_sqlite(clean_path, "SELECT COUNT(*) FROM species;"),
             clean_count = String.trim(count_str) |> String.to_integer(),
             true <- clean_count == species_count do
          Mix.Shell.IO.info("#{@green}✓ Clean copy verified#{@reset}")

          # Get file size and checksum
          %{size: size} = File.stat!(clean_path)
          file_size = human_readable_size(size)

          {checksum, 0} = System.cmd("shasum", ["-a", "256", clean_path])
          checksum = checksum |> String.split() |> hd()

          Mix.Shell.IO.info("File size: #{file_size}")
          Mix.Shell.IO.info("SHA-256: #{checksum}\n")

          {:ok, clean_path, checksum}
        else
          {:ok, result} ->
            cleanup_temp_file(clean_path)
            {:error, "Clean copy failed integrity check: #{result}"}

          false ->
            cleanup_temp_file(clean_path)
            {:error, "Species count mismatch after VACUUM"}

          {:error, reason} ->
            cleanup_temp_file(clean_path)
            {:error, "Failed to verify clean copy: #{reason}"}
        end

      {:error, reason} ->
        cleanup_temp_file(clean_path)
        {:error, "Failed to create clean copy: #{reason}"}
    end
  end

  ## Step 5: Confirm with User

  defp confirm_replacement(species_count, clean_path) do
    %{size: size} = File.stat!(clean_path)
    file_size = human_readable_size(size)

    Mix.Shell.IO.info(
      "#{@yellow}WARNING: This will replace the production database on Fly.io#{@reset}"
    )

    Mix.Shell.IO.info("App: #{@app_name}")
    Mix.Shell.IO.info("Species count: #{species_count}")
    Mix.Shell.IO.info("File size: #{file_size}")
    Mix.Shell.IO.info("\nThe existing database will be backed up with a timestamp.")
    Mix.Shell.IO.info("If anything fails, you can rollback to the backup.\n")

    if Mix.Shell.IO.prompt("Type 'REPLACE' to continue: ") == "REPLACE" do
      Mix.Shell.IO.info("")
      :ok
    else
      cleanup_temp_file(clean_path)
      {:error, :user_cancelled}
    end
  end

  ## Step 6: Get Machine Info

  defp get_machine_info do
    Mix.Shell.IO.info("#{@blue}=== Step 2: Get Machine Info ===#{@reset}")

    case System.cmd("fly", ["machine", "list", "-a", @app_name, "--json"]) do
      {output, 0} ->
        machines = Jason.decode!(output)

        case machines do
          [machine | _] ->
            machine_id = machine["id"]
            machine_state = machine["state"]

            Mix.Shell.IO.info("Machine ID: #{machine_id}")
            Mix.Shell.IO.info("Machine state: #{machine_state}\n")

            {:ok, machine_id, machine_state}

          [] ->
            {:error, "No machines found"}
        end

      {error, _} ->
        {:error, "Failed to get machine info: #{error}"}
    end
  end

  ## Step 7: Stop Machine

  defp stop_machine(machine_id, machine_state) do
    Mix.Shell.IO.info("#{@blue}=== Step 3: Stop Machine ===#{@reset}")

    if machine_state == "started" do
      Mix.Shell.IO.info("Stopping machine...")

      case System.cmd("fly", ["machine", "stop", machine_id, "-a", @app_name]) do
        {_, 0} ->
          Mix.Shell.IO.info("#{@green}✓ Machine stopped#{@reset}\n")
          :ok

        {error, _} ->
          {:error, "Failed to stop machine: #{error}"}
      end
    else
      Mix.Shell.IO.info("Machine already stopped\n")
      :ok
    end
  end

  ## Step 8: Update to Sleep Mode

  defp update_to_sleep_mode(machine_id) do
    Mix.Shell.IO.info("#{@blue}=== Step 4: Update Machine to Sleep Mode ===#{@reset}")

    Mix.Shell.IO.info("Updating machine command to 'sleep infinity'...")

    update_cmd = [
      "machine",
      "update",
      machine_id,
      "--app",
      @app_name,
      "--command",
      "sleep infinity",
      "--yes"
    ]

    case System.cmd("fly", update_cmd) do
      {_, 0} ->
        Mix.Shell.IO.info("#{@green}✓ Machine updated to sleep mode#{@reset}\n")
        :ok

      {error, _} ->
        {:error, "Failed to update machine: #{error}"}
    end
  end

  ## Step 9: Start Sleeping Machine

  defp start_sleeping_machine(machine_id) do
    Mix.Shell.IO.info("#{@blue}=== Step 5: Start Sleeping Machine ===#{@reset}")

    Mix.Shell.IO.info("Starting machine (will run 'sleep infinity', not the app)...")

    case System.cmd("fly", ["machine", "start", machine_id, "-a", @app_name]) do
      {_, 0} ->
        Mix.Shell.IO.info("Waiting for machine to start...")
        Process.sleep(5000)
        Mix.Shell.IO.info("#{@green}✓ Machine started (DB lock released)#{@reset}\n")
        :ok

      {error, _} ->
        {:error, "Failed to start machine: #{error}"}
    end
  end

  ## Step 10: Backup Existing Database

  defp backup_existing_db(machine_id) do
    Mix.Shell.IO.info("#{@blue}=== Step 6: Backup Existing Database ===#{@reset}")

    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M%S")
    backup_file = "/data/gallformers-#{timestamp}.sqlite.bak"

    Mix.Shell.IO.info("Backup filename: #{backup_file}")

    # Check if database exists
    test_cmd = [
      "ssh",
      "console",
      "-a",
      @app_name,
      "--machine",
      machine_id,
      "-C",
      "test -f #{@db_path}"
    ]

    case System.cmd("fly", test_cmd, stderr_to_stdout: true) do
      {_, 0} ->
        # Database exists, move it to backup (use mv not cp)
        Mix.Shell.IO.info("Moving existing database to backup...")

        mv_cmd = [
          "ssh",
          "console",
          "-a",
          @app_name,
          "--machine",
          machine_id,
          "-C",
          "mv #{@db_path} #{backup_file}"
        ]

        case System.cmd("fly", mv_cmd) do
          {_, 0} ->
            Mix.Shell.IO.info("#{@green}✓ Backup created: #{backup_file}#{@reset}\n")
            {:ok, backup_file}

          {error, _} ->
            {:error, "Failed to create backup: #{error}"}
        end

      _ ->
        Mix.Shell.IO.info("#{@yellow}No existing database found (fresh install)#{@reset}\n")
        {:ok, nil}
    end
  end

  ## Step 11: Upload Database

  defp upload_database(machine_id, clean_db_path, backup_file) do
    Mix.Shell.IO.info("#{@blue}=== Step 7: Upload New Database ===#{@reset}")

    %{size: size} = File.stat!(clean_db_path)
    file_size = human_readable_size(size)

    Mix.Shell.IO.info("Uploading database (#{file_size})...")

    # Use SFTP to upload
    sftp_commands = "put #{clean_db_path} #{@db_path}"

    sftp_cmd = ["sftp", "shell", "--app", @app_name, "--machine", machine_id]

    case System.cmd("fly", sftp_cmd, input: sftp_commands, stderr_to_stdout: true) do
      {_output, 0} ->
        Mix.Shell.IO.info("#{@green}✓ Database uploaded#{@reset}\n")
        :ok

      {error, _} ->
        {:error, "Upload failed: #{error}",
         %{machine_id: machine_id, backup_file: backup_file, can_rollback: true}}
    end
  end

  ## Step 12: Verify Remote Database

  defp verify_remote_db(machine_id, expected_species_count, backup_file) do
    Mix.Shell.IO.info("#{@blue}=== Step 8: Verify Remote Database ===#{@reset}")

    # Check integrity
    Mix.Shell.IO.info("Checking integrity on remote...")

    integrity_cmd = [
      "ssh",
      "console",
      "-a",
      @app_name,
      "--machine",
      machine_id,
      "-C",
      "sqlite3 #{@db_path} 'PRAGMA integrity_check;'"
    ]

    case System.cmd("fly", integrity_cmd) do
      {"ok\n", 0} ->
        Mix.Shell.IO.info("#{@green}✓ Remote integrity check passed#{@reset}")

        # Check species count
        count_cmd = [
          "ssh",
          "console",
          "-a",
          @app_name,
          "--machine",
          machine_id,
          "-C",
          "sqlite3 #{@db_path} 'SELECT COUNT(*) FROM species;'"
        ]

        case System.cmd("fly", count_cmd) do
          {count_str, 0} ->
            remote_count = String.trim(count_str) |> String.to_integer()
            Mix.Shell.IO.info("Remote species count: #{remote_count}")

            if remote_count == expected_species_count do
              Mix.Shell.IO.info("#{@green}✓ Remote species count matches#{@reset}\n")
              :ok
            else
              {:error,
               "Species count mismatch! Local: #{expected_species_count}, Remote: #{remote_count}",
               %{machine_id: machine_id, backup_file: backup_file, can_rollback: true}}
            end

          {error, _} ->
            {:error, "Failed to count species on remote: #{error}",
             %{machine_id: machine_id, backup_file: backup_file, can_rollback: true}}
        end

      {result, _} ->
        {:error, "Remote database failed integrity check: #{result}",
         %{machine_id: machine_id, backup_file: backup_file, can_rollback: true}}
    end
  end

  ## Step 13: Clear Litestream Backups

  defp clear_litestream_backups do
    Mix.Shell.IO.info("#{@blue}=== Step 9: Clear Litestream Backups ===#{@reset}")

    Mix.Shell.IO.info("Clearing Litestream backups from S3 (forces fresh generation)...")

    case System.cmd("aws", ["s3", "rm", "s3://gallformers-backups/litestream/", "--recursive"]) do
      {_, 0} ->
        Mix.Shell.IO.info("#{@green}✓ Litestream backups cleared#{@reset}\n")
        :ok

      {error, _} ->
        Mix.Shell.IO.info(
          "#{@yellow}Warning: Failed to clear Litestream backups: #{error}#{@reset}"
        )

        Mix.Shell.IO.info("You may need to clear them manually later\n")
        :ok
    end
  end

  ## Step 14: Restore Normal Operation

  defp restore_normal_operation(machine_id) do
    Mix.Shell.IO.info("#{@blue}=== Step 10: Restore Normal Operation ===#{@reset}")

    Mix.Shell.IO.info("Clearing command override (reverts to Dockerfile CMD)...")

    update_cmd = [
      "machine",
      "update",
      machine_id,
      "--app",
      @app_name,
      "--command",
      "",
      "--yes"
    ]

    case System.cmd("fly", update_cmd) do
      {_, 0} ->
        Mix.Shell.IO.info("#{@green}✓ Command override cleared#{@reset}")
        Mix.Shell.IO.info("Restarting machine...")

        case System.cmd("fly", ["machine", "restart", machine_id, "-a", @app_name]) do
          {_, 0} ->
            Mix.Shell.IO.info("Waiting for machine to start...")
            Process.sleep(10_000)

            # Check status
            Mix.Shell.IO.info("Checking machine status...")
            System.cmd("fly", ["status", "-a", @app_name]) |> elem(0) |> Mix.Shell.IO.info()

            # Check health endpoint
            Mix.Shell.IO.info("\nChecking health endpoint...")

            case System.cmd("curl", ["-f", "-s", "https://gallformers.fly.dev/health"]) do
              {_, 0} ->
                Mix.Shell.IO.info("#{@green}✓ Health check passed#{@reset}\n")
                :ok

              _ ->
                Mix.Shell.IO.info("#{@yellow}Warning: Health check failed or timed out#{@reset}")
                Mix.Shell.IO.info("Check logs: fly logs -a #{@app_name}\n")
                :ok
            end

          {error, _} ->
            {:error, "Failed to restart machine: #{error}"}
        end

      {error, _} ->
        {:error, "Failed to update machine command: #{error}"}
    end
  end

  ## Success Summary

  defp print_success_summary(species_count, clean_db_path, checksum, backup_file) do
    %{size: size} = File.stat!(clean_db_path)
    file_size = human_readable_size(size)

    Mix.Shell.IO.info("#{@green}=== Database Update Complete ===#{@reset}\n")
    Mix.Shell.IO.info("Summary:")
    Mix.Shell.IO.info("  Species count: #{species_count}")
    Mix.Shell.IO.info("  File size: #{file_size}")
    Mix.Shell.IO.info("  SHA-256: #{checksum}")

    if backup_file do
      Mix.Shell.IO.info("  Backup: #{backup_file}")
    end

    Mix.Shell.IO.info("\nNext steps:")
    Mix.Shell.IO.info("  1. Verify site: https://gallformers.fly.dev/")
    Mix.Shell.IO.info("  2. Check logs: fly logs -a #{@app_name}")

    if backup_file do
      Mix.Shell.IO.info(
        "  3. Remove backup once confirmed: fly ssh console -C 'rm #{backup_file}'"
      )
    end

    Mix.Shell.IO.info("")
  end

  ## Error Recovery

  defp handle_error_recovery(%{machine_id: machine_id, backup_file: backup_file, can_rollback: true}) do
    if backup_file do
      if Mix.Shell.IO.yes?("Attempt rollback?") do
        attempt_rollback(machine_id, backup_file)
      else
        Mix.Shell.IO.info(
          "#{@yellow}Machine is still sleeping. You can investigate or restore manually.#{@reset}"
        )

        Mix.Shell.IO.info("Backup location: #{backup_file}")
      end
    else
      Mix.Shell.IO.info("#{@yellow}No backup available for rollback.#{@reset}")
      Mix.Shell.IO.info("Machine is still sleeping. You can investigate manually.")
    end
  end

  defp handle_error_recovery(_context), do: :ok

  defp attempt_rollback(machine_id, backup_file) do
    Mix.Shell.IO.info("#{@yellow}Attempting rollback...#{@reset}")

    # Restore backup (mv it back)
    restore_cmd = [
      "ssh",
      "console",
      "-a",
      @app_name,
      "--machine",
      machine_id,
      "-C",
      "mv #{backup_file} #{@db_path}"
    ]

    case System.cmd("fly", restore_cmd) do
      {_, 0} ->
        Mix.Shell.IO.info("#{@green}✓ Backup restored#{@reset}")

        # Restart machine normally
        Mix.Shell.IO.info("Clearing command override and restarting...")

        System.cmd("fly", [
          "machine",
          "update",
          machine_id,
          "--app",
          @app_name,
          "--command",
          "",
          "--yes"
        ])

        System.cmd("fly", ["machine", "restart", machine_id, "-a", @app_name])

        Mix.Shell.IO.info("#{@green}Rollback complete#{@reset}")

      {error, _} ->
        Mix.Shell.IO.error("#{@red}Rollback failed: #{error}#{@reset}")
    end
  end

  ## Helpers

  defp run_sqlite(db_path, query) do
    case System.cmd("sqlite3", [db_path, query], stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {error, _} -> {:error, error}
    end
  end

  defp human_readable_size(bytes) do
    cond do
      bytes >= 1_073_741_824 -> "#{Float.round(bytes / 1_073_741_824, 2)} GB"
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 2)} MB"
      bytes >= 1024 -> "#{Float.round(bytes / 1024, 2)} KB"
      true -> "#{bytes} B"
    end
  end

  defp cleanup_temp_file(path) do
    if File.exists?(path) do
      path |> Path.dirname() |> File.rm_rf()
    end
  end
end
