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

  @shortdoc "Build WCVP Postgres database from CSV files"

  @default_names "priv/repo/data/wcvp/wcvp_names.csv"
  @default_dist "priv/repo/data/wcvp/wcvp_distribution.csv"

  @s3_bucket "gallformers-backups"
  @s3_key "public/wcvp.dump"

  @batch_size 1000

  @names_columns ~w[
    plant_name_id ipni_id taxon_rank taxon_status family genus_hybrid genus
    species_hybrid species infraspecific_rank infraspecies parenthetical_author
    primary_author publication_author place_of_publication volume_and_page
    first_published nomenclatural_remarks geographic_area lifeform_description
    climate_description taxon_name taxon_authors accepted_plant_name_id
    basionym_plant_name_id replaced_synonym_author homotypic_synonym
    parent_plant_name_id powo_id hybrid_formula reviewed
  ]

  @dist_columns ~w[
    plant_locality_id plant_name_id continent_code_l1 continent region_code_l2
    region area_code_l3 area introduced extinct location_doubtful
  ]

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

    # Insert all data
    names_count = insert_rows(conn, "wcvp_names", @names_columns, names_path)
    Logger.info("  Inserted #{names_count} name records")

    dist_count = insert_rows(conn, "wcvp_distributions", @dist_columns, dist_path)
    Logger.info("  Inserted #{dist_count} distribution records")

    insert_meta(conn)

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
    # Derive connection config from Repo.WCVP configuration
    repo_config = Application.get_env(:gallformers, Gallformers.Repo.WCVP, [])

    conn_opts = [
      database: repo_config[:database] || "wcvp",
      username: repo_config[:username] || System.get_env("PGUSER") || System.get_env("USER"),
      password: repo_config[:password] || System.get_env("PGPASSWORD"),
      hostname: repo_config[:hostname] || System.get_env("PGHOST") || "localhost"
    ]

    {:ok, conn} = Postgrex.start_link(conn_opts)
    conn
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
    {placeholder_groups, flat_params, _idx} =
      Enum.reduce(lines, {[], [], 1}, fn line, {groups, params, idx} ->
        values = line |> String.split("|") |> pad_values(col_count)

        group =
          Enum.map_join(idx..(idx + col_count - 1), ", ", fn i -> "$#{i}" end)

        {groups ++ ["(#{group})"], params ++ values, idx + col_count}
      end)

    {Enum.join(placeholder_groups, ", "), flat_params}
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

    data = File.read!(dump_path)
    File.rm(dump_path)

    Logger.info("Uploading to s3://#{@s3_bucket}/#{@s3_key}...")

    case ExAws.S3.put_object(@s3_bucket, @s3_key, data) |> Gallformers.S3.request() do
      {:ok, _} ->
        Logger.info("Upload complete")

      {:error, reason} ->
        Logger.error("Upload failed: #{inspect(reason)}")
    end
  end

  defp pg_dump(dump_path) do
    repo_config = Application.get_env(:gallformers, Gallformers.Repo.WCVP, [])
    database = repo_config[:database] || "wcvp"
    hostname = repo_config[:hostname] || System.get_env("PGHOST") || "localhost"

    Logger.info("Dumping #{database} to #{dump_path}...")

    args = ["-Fc", "-h", hostname, "-d", database, "-f", dump_path]

    args =
      case repo_config[:username] do
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
