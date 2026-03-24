defmodule Mix.Tasks.MigrateArticles do
  use Boundary, check: [in: false, out: false]

  @moduledoc """
  Migrates V1 reference articles from markdown files to the database.

  ## Usage

      mix migrate_articles

  This task reads markdown files from the /ref directory at the project root,
  parses their YAML frontmatter, and inserts them as published articles.
  """
  use Mix.Task

  alias Gallformers.Articles

  @shortdoc "Migrates V1 reference articles to the database"

  @ref_dir Path.expand("../../../../ref", __DIR__)

  # Tag assignments based on article content/type
  @article_tags %{
    "IDGuide" => ["identification", "guide"],
    "contributing" => ["meta", "contributing"],
    "patrons" => ["meta", "supporters"],
    "populusaphidkey" => ["identification", "keys", "aphids", "populus"],
    "populusmidgekey" => ["identification", "keys", "midges", "populus"],
    "undescribedfaq" => ["faq", "taxonomy"],
    "vitisgallkey" => ["identification", "keys", "vitis"]
  }

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    IO.puts("Migrating V1 reference articles from #{@ref_dir}...")

    case File.ls(@ref_dir) do
      {:ok, files} ->
        md_files = Enum.filter(files, &String.ends_with?(&1, ".md"))
        IO.puts("Found #{length(md_files)} markdown files")

        results =
          Enum.map(md_files, fn filename ->
            migrate_file(filename)
          end)

        successful = Enum.count(results, &match?({:ok, _}, &1))
        skipped = Enum.count(results, &match?({:skipped, _}, &1))
        failed = Enum.count(results, &match?({:error, _, _}, &1))

        IO.puts("\nMigration complete:")
        IO.puts("  - #{successful} articles created")
        IO.puts("  - #{skipped} articles skipped (already exist)")
        IO.puts("  - #{failed} articles failed")

      {:error, reason} ->
        IO.puts("Error reading ref directory: #{inspect(reason)}")
        IO.puts("Make sure the /ref directory exists at: #{@ref_dir}")
    end
  end

  defp migrate_file(filename) do
    filepath = Path.join(@ref_dir, filename)
    slug = String.replace(filename, ".md", "") |> String.downcase()

    IO.write("  Migrating #{filename}... ")

    # Check if article already exists
    if Articles.get_article_by_slug(slug) do
      IO.puts("SKIPPED (already exists)")
      {:skipped, filename}
    else
      migrate_new_article(filepath, slug, filename)
    end
  end

  defp migrate_new_article(filepath, slug, filename) do
    with {:ok, content} <- File.read(filepath),
         {:ok, frontmatter, body} <- parse_frontmatter(content) do
      create_article(slug, frontmatter, body, filename)
    else
      {:error, reason} when is_binary(reason) ->
        IO.puts("FAILED (#{reason})")
        {:error, filename, reason}

      {:error, reason} ->
        IO.puts("FAILED (read error: #{inspect(reason)})")
        {:error, filename, reason}
    end
  end

  defp parse_frontmatter(content) do
    case String.split(content, "---", parts: 3) do
      ["", frontmatter_str, body] ->
        frontmatter = parse_yaml_simple(frontmatter_str)
        {:ok, frontmatter, String.trim(body)}

      _ ->
        {:error, "No valid frontmatter found"}
    end
  end

  # Simple YAML parser for the frontmatter format used in these files
  defp parse_yaml_simple(yaml_str) do
    yaml_str
    |> String.split("\n")
    |> Enum.reduce(%{}, &parse_yaml_line/2)
  end

  defp parse_yaml_line(line, acc) do
    line = String.trim(line)

    cond do
      line == "" ->
        acc

      String.starts_with?(line, "name:") ->
        value = extract_value(line, "name:")
        Map.put(acc, "author", value)

      String.contains?(line, ":") and not String.starts_with?(line, " ") ->
        parse_top_level_key(line, acc)

      true ->
        acc
    end
  end

  defp parse_top_level_key(line, acc) do
    [key | rest] = String.split(line, ":", parts: 2)
    value = rest |> Enum.join(":") |> String.trim() |> String.trim("'") |> String.trim("\"")

    if value != "", do: Map.put(acc, String.trim(key), value), else: acc
  end

  defp extract_value(line, prefix) do
    line
    |> String.replace_prefix(prefix, "")
    |> String.trim()
    |> String.trim("'")
    |> String.trim("\"")
  end

  defp create_article(slug, frontmatter, body, filename) do
    base_name = String.replace(filename, ".md", "")
    tags = Map.get(@article_tags, base_name, [])

    attrs = %{
      slug: slug,
      title: Map.get(frontmatter, "title", base_name),
      author: Map.get(frontmatter, "author", "Gallformers"),
      content: body,
      tags: tags,
      is_published: true
    }

    case Articles.create_article(attrs) do
      {:ok, article} ->
        IO.puts("OK (id: #{article.id})")
        {:ok, article}

      {:error, changeset} ->
        errors = format_errors(changeset)
        IO.puts("FAILED (#{errors})")
        {:error, filename, errors}
    end
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map_join("; ", fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
  end
end
