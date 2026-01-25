defmodule Mix.Tasks.Migrations.Lint do
  @shortdoc "Checks migrations for unsafe patterns"
  @moduledoc """
  Lints migration files for unsafe SQLite patterns.

  ## Checks

  1. **Direct Ecto.Migration usage**: Migrations should use `Gallformers.Migration`
     instead of `Ecto.Migration` to ensure safe DDL transaction handling.

  2. **DROP TABLE without protection**: Any migration containing `DROP TABLE`
     must either use `Gallformers.Migration` or explicitly set
     `@disable_ddl_transaction true`.

  ## Skipping Checks

  Migrations created before this lint was introduced are grandfathered in.
  The cutoff is defined by `@skip_before_version`.

  To skip a specific migration, add this comment anywhere in the file:

      # migrations.lint: skip

  ## Usage

      mix migrations.lint

  Returns exit code 1 if any issues are found, 0 otherwise.
  Designed to be used in CI pipelines.
  """

  use Mix.Task

  @migrations_path "priv/repo/migrations"

  # Migrations created before this version are grandfathered in
  # This was when Gallformers.Migration was introduced
  @skip_before_version 20_260_126_000_000

  @impl Mix.Task
  def run(_args) do
    migrations_dir = Path.join(File.cwd!(), @migrations_path)

    migrations =
      migrations_dir
      |> Path.join("*.exs")
      |> Path.wildcard()
      |> Enum.sort()
      |> Enum.reject(&skip_migration?/1)

    issues =
      migrations
      |> Enum.flat_map(&check_migration/1)

    if issues == [] do
      Mix.shell().info("✓ All #{length(migrations)} migrations passed lint checks")
    else
      Mix.shell().error("Migration lint found #{length(issues)} issue(s):\n")

      Enum.each(issues, fn {file, line, message} ->
        relative = Path.relative_to_cwd(file)
        Mix.shell().error("  #{relative}:#{line}: #{message}")
      end)

      Mix.raise("Migration lint failed")
    end
  end

  defp check_migration(path) do
    content = File.read!(path)
    lines = String.split(content, "\n")

    issues = []

    # Check 1: Uses Ecto.Migration directly instead of Gallformers.Migration
    issues =
      case find_line(lines, ~r/use Ecto\.Migration\b/) do
        nil ->
          issues

        line_num ->
          # Check if it's Gallformers.Migration (which uses Ecto.Migration internally)
          if String.contains?(content, "defmodule Gallformers.Migration") do
            # This IS the Gallformers.Migration module, skip
            issues
          else
            [
              {path, line_num,
               "Uses `Ecto.Migration` directly. Use `Gallformers.Migration` instead for SQLite safety."}
              | issues
            ]
          end
      end

    # Check 2: Has DROP TABLE without @disable_ddl_transaction
    issues =
      case find_line(lines, ~r/DROP TABLE/i) do
        nil ->
          issues

        line_num ->
          has_disable_ddl =
            String.contains?(content, "@disable_ddl_transaction true") or
              String.contains?(content, "use Gallformers.Migration")

          if has_disable_ddl do
            issues
          else
            [
              {path, line_num,
               "Contains `DROP TABLE` without `@disable_ddl_transaction true` or `Gallformers.Migration`. This can cause silent data loss."}
              | issues
            ]
          end
      end

    issues
  end

  defp find_line(lines, pattern) do
    Enum.find_value(Enum.with_index(lines, 1), fn {line, num} ->
      if Regex.match?(pattern, line), do: num
    end)
  end

  defp skip_migration?(path) do
    filename = Path.basename(path)

    # Extract version number from filename (e.g., 20260125012931_name.exs)
    case Regex.run(~r/^(\d+)_/, filename) do
      [_, version_str] ->
        version = String.to_integer(version_str)

        if version < @skip_before_version do
          true
        else
          # Also check for explicit skip comment
          content = File.read!(path)
          String.contains?(content, "# migrations.lint: skip")
        end

      _ ->
        false
    end
  end
end
