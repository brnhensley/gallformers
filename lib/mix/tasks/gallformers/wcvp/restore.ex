defmodule Mix.Tasks.Gallformers.Wcvp.Restore do
  @moduledoc """
  Restores the WCVP database from a pg_dump artifact on S3.

  Downloads the dump file and runs pg_restore to load it into the local
  wcvp database. Used for developer setup and environment bootstrapping.

  ## Usage

      mix gallformers.wcvp.restore [options]

  ## Options

      --database  Target database name (default: "wcvp")
      --url       URL of the pg_dump file (default: S3 public bucket)
  """

  use Mix.Task
  require Logger

  @shortdoc "Restore WCVP database from S3 pg_dump"

  @s3_base "https://gallformers-backups.s3.amazonaws.com/public"
  @default_url "#{@s3_base}/wcvp.dump"

  @impl Mix.Task
  def run(args) do
    opts = parse_args(args)
    database = opts[:database]
    url = opts[:url]

    tmp_path =
      Path.join(System.tmp_dir!(), "wcvp_restore_#{System.unique_integer([:positive])}.dump")

    Logger.info("Restoring WCVP database...")
    Logger.info("  Database: #{database}")
    Logger.info("  Source: #{url}")

    ensure_database(database)
    download(url, tmp_path)
    pg_restore(database, tmp_path)
    File.rm(tmp_path)
    verify(database)
  end

  defp ensure_database(database) do
    case System.cmd("createdb", [database], stderr_to_stdout: true) do
      {_, 0} ->
        Logger.info("  Created database #{database}")

      {msg, _} ->
        if msg =~ "already exists" do
          Logger.info("  Database #{database} already exists")
        else
          Mix.raise("Failed to create database #{database}: #{msg}")
        end
    end
  end

  defp download(url, tmp_path) do
    Logger.info("  Downloading dump file...")
    Mix.Task.run("app.start")

    case Req.get(url, into: File.stream!(tmp_path)) do
      {:ok, %Req.Response{status: 200}} ->
        Logger.info("  Download complete")

      {:ok, %Req.Response{status: status}} ->
        File.rm(tmp_path)
        Mix.raise("Download failed with status #{status}")

      {:error, reason} ->
        File.rm(tmp_path)
        Mix.raise("Download failed: #{inspect(reason)}")
    end
  end

  defp pg_restore(database, tmp_path) do
    Logger.info("  Running pg_restore...")

    args = ["--clean", "--if-exists", "--no-owner", "--no-acl", "-d", database, tmp_path]

    case System.cmd("pg_restore", args, stderr_to_stdout: true) do
      {_, 0} ->
        Logger.info("  Restore complete")

      {output, _exit_code} ->
        # pg_restore returns non-zero for warnings (e.g., "does not exist" on clean).
        # Only fail if there are actual errors beyond expected cleanup warnings.
        if output =~ "FATAL" or output =~ "could not connect" do
          File.rm(tmp_path)
          Mix.raise("pg_restore failed: #{output}")
        else
          Logger.info("  Restore complete (with expected warnings)")
        end
    end
  end

  defp verify(database) do
    Logger.info("  Verifying...")
    config = Application.get_env(:gallformers, Gallformers.Repo.WCVP)
    {:ok, conn} = Postgrex.start_link(Keyword.put(config, :database, database))

    case Postgrex.query(conn, "SELECT COUNT(*) FROM wcvp_names", []) do
      {:ok, %{rows: [[count]]}} ->
        Logger.info("WCVP database restored: #{count} name records")

      {:error, reason} ->
        Logger.warning("Could not verify: #{inspect(reason)}")
    end

    GenServer.stop(conn)
  end

  @doc false
  def parse_args(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [database: :string, url: :string]
      )

    [
      database: opts[:database] || "wcvp",
      url: opts[:url] || @default_url
    ]
  end

  @doc false
  def default_url, do: @default_url
end
