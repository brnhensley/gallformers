defmodule Mix.Tasks.Gallformers.Wcvp.BuildDb do
  @moduledoc """
  Reads raw WCVP CSV files and loads ALL data into the WCVP Postgres database —
  no filtering by taxon_status, taxon_rank, or TDWG region.

  The task opens a direct Postgrex connection (not through Repo.WCVP) and manages
  the entire lifecycle: drop existing tables, create tables, bulk insert data,
  create indexes.

  ## Usage

      mix gallformers.wcvp.build_db [options]

  ## Options

      --names   Path to wcvp_names.csv (default: priv/repo/data/wcvp/wcvp_names.csv)
      --dist    Path to wcvp_distribution.csv (default: priv/repo/data/wcvp/wcvp_distribution.csv)
      --upload  Upload pg_dump to S3 after building
  """

  use Mix.Task
  require Logger

  alias Gallformers.Wcvp.Conn, as: WcvpConn

  @shortdoc "Build WCVP Postgres database from CSV files"

  @default_names "priv/repo/data/wcvp/wcvp_names.csv"
  @default_dist "priv/repo/data/wcvp/wcvp_distribution.csv"

  @s3_bucket "gallformers-backups"
  @s3_key "public/wcvp.dump"

  alias ExAws.S3, as: AwsS3
  alias Gallformers.S3
  alias Gallformers.Wcvp.{WcvpDistribution, WcvpName}

  @batch_size 1000

  # Derive column lists from the Ecto schemas — single source of truth
  @names_columns WcvpName.__schema__(:fields) |> Enum.map(&Atom.to_string/1)
  @dist_columns WcvpDistribution.__schema__(:fields) |> Enum.map(&Atom.to_string/1)

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [names: :string, dist: :string, upload: :boolean]
      )

    names_path = opts[:names] || @default_names
    dist_path = opts[:dist] || @default_dist

    Logger.info("Building WCVP Postgres database...")
    Logger.info("  Names: #{names_path}")
    Logger.info("  Distributions: #{dist_path}")

    conn = connect!()

    # Drop and recreate tables
    drop_tables(conn)
    create_names_table(conn)
    create_distributions_table(conn)
    create_meta_table(conn)

    # Insert all data in a single transaction for atomicity and performance
    Postgrex.query!(conn, "BEGIN", [])

    names_count = insert_rows(conn, "wcvp_names", @names_columns, names_path)
    Logger.info("  Inserted #{names_count} name records")

    dist_count = insert_rows(conn, "wcvp_distributions", @dist_columns, dist_path)
    Logger.info("  Inserted #{dist_count} distribution records")

    insert_meta(conn)

    Postgrex.query!(conn, "COMMIT", [])

    # Create indexes after bulk insert for performance
    create_indexes(conn)

    GenServer.stop(conn)

    Logger.info("WCVP database built successfully")

    if opts[:upload] do
      upload_to_s3()
    end
  end

  @doc false
  def connect! do
    WcvpConn.start_link!()
  end

  defp drop_tables(conn) do
    Postgrex.query!(conn, "DROP TABLE IF EXISTS wcvp_distributions CASCADE", [])
    Postgrex.query!(conn, "DROP TABLE IF EXISTS wcvp_names CASCADE", [])
    Postgrex.query!(conn, "DROP TABLE IF EXISTS meta CASCADE", [])
  end

  defp create_names_table(conn) do
    col_defs =
      Enum.map_join(@names_columns, ", ", fn col ->
        if col == "plant_name_id",
          do: "plant_name_id TEXT PRIMARY KEY",
          else: "#{col} TEXT"
      end)

    Postgrex.query!(conn, "CREATE TABLE wcvp_names (#{col_defs})", [])
  end

  defp create_distributions_table(conn) do
    col_defs =
      Enum.map_join(@dist_columns, ", ", fn col ->
        if col == "plant_locality_id",
          do: "plant_locality_id TEXT PRIMARY KEY",
          else: "#{col} TEXT"
      end)

    Postgrex.query!(conn, "CREATE TABLE wcvp_distributions (#{col_defs})", [])
  end

  defp create_meta_table(conn) do
    Postgrex.query!(
      conn,
      "CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)",
      []
    )
  end

  defp insert_rows(conn, table, columns, csv_path) do
    col_count = length(columns)
    col_names = Enum.join(columns, ", ")

    # Validate CSV header matches expected columns
    [header_line | _] = File.stream!(csv_path) |> Enum.take(1)
    csv_columns = header_line |> String.trim() |> String.split("|")

    if csv_columns != columns do
      raise """
      CSV column mismatch in #{csv_path}.
      Expected: #{inspect(columns)}
      Got:      #{inspect(csv_columns)}
      """
    end

    csv_path
    |> File.stream!()
    |> Stream.drop(1)
    |> Stream.map(&String.trim/1)
    |> Stream.reject(&(&1 == ""))
    |> Stream.chunk_every(@batch_size)
    |> Enum.reduce(0, fn batch, total ->
      {placeholders, flat_params} = build_batch_params(batch, col_count)

      sql = "INSERT INTO #{table} (#{col_names}) VALUES #{placeholders}"
      Postgrex.query!(conn, sql, flat_params)

      total + length(batch)
    end)
  end

  defp build_batch_params(lines, col_count) do
    {rev_groups, rev_params, _idx} =
      Enum.reduce(lines, {[], [], 1}, fn line, {groups, params, idx} ->
        values = line |> String.split("|") |> pad_values(col_count)

        group =
          Enum.map_join(idx..(idx + col_count - 1), ", ", fn i -> "$#{i}" end)

        {["(#{group})" | groups], [values | params], idx + col_count}
      end)

    placeholders = rev_groups |> Enum.reverse() |> Enum.join(", ")
    flat_params = rev_params |> Enum.reverse() |> List.flatten()
    {placeholders, flat_params}
  end

  defp pad_values(values, expected) do
    actual = length(values)

    cond do
      actual == expected -> values
      actual < expected -> values ++ List.duplicate("", expected - actual)
      true -> Enum.take(values, expected)
    end
  end

  defp insert_meta(conn) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

    Postgrex.query!(
      conn,
      "INSERT INTO meta (key, value) VALUES ($1, $2)",
      ["built_at", timestamp]
    )
  end

  defp create_indexes(conn) do
    indexes = [
      "CREATE INDEX idx_wcvp_names_taxon_name ON wcvp_names(lower(taxon_name) text_pattern_ops)",
      "CREATE INDEX idx_wcvp_names_genus ON wcvp_names(genus)",
      "CREATE INDEX idx_wcvp_names_family ON wcvp_names(family)",
      "CREATE INDEX idx_wcvp_names_accepted ON wcvp_names(accepted_plant_name_id)",
      "CREATE INDEX idx_wcvp_names_status ON wcvp_names(taxon_status)",
      "CREATE INDEX idx_wcvp_dist_name_id ON wcvp_distributions(plant_name_id)",
      "CREATE INDEX idx_wcvp_dist_area ON wcvp_distributions(area_code_l3)"
    ]

    Enum.each(indexes, fn sql -> Postgrex.query!(conn, sql, []) end)
  end

  defp upload_to_s3 do
    Mix.Task.run("app.start")

    dump_path = Path.join(System.tmp_dir!(), "wcvp.dump")
    pg_dump(dump_path)

    Logger.info("Uploading to s3://#{@s3_bucket}/#{@s3_key}...")

    # Stream the dump file in chunks to avoid loading it all into memory.
    # The WCVP dump can be 100-300MB; multipart upload handles this efficiently.
    result =
      dump_path
      |> AwsS3.Upload.stream_file()
      |> AwsS3.upload(@s3_bucket, @s3_key)
      |> S3.request()

    case result do
      {:ok, _} ->
        Logger.info("Upload complete")

      {:error, reason} ->
        Logger.error("Upload failed: #{inspect(reason)}")
    end

    File.rm(dump_path)
  end

  defp pg_dump(dump_path) do
    conn_opts = WcvpConn.opts()
    database = conn_opts[:database]
    hostname = conn_opts[:hostname]

    Logger.info("Dumping #{database} to #{dump_path}...")

    args = ["-Fc", "-h", hostname, "-d", database, "-f", dump_path]

    args =
      case conn_opts[:username] do
        nil -> args
        user -> ["-U", user | args]
      end

    case System.cmd("pg_dump", args, stderr_to_stdout: true) do
      {_, 0} ->
        :ok

      {output, code} ->
        Logger.error("pg_dump failed (exit #{code}): #{output}")
        raise "pg_dump failed"
    end
  end
end
