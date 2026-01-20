#!/usr/bin/env elixir
# Script to generate a migration that seeds articles data
# Run with: mix run scripts/generate_articles_seed_migration.exs

defmodule GenerateArticlesSeedMigration do
  def run do
    # Query articles from the database
    {:ok, conn} = Exqlite.Sqlite3.open("priv/gallformers.sqlite")
    {:ok, stmt} = Exqlite.Sqlite3.prepare(conn, "SELECT id, slug, title, author, content, tags, is_published, inserted_at, updated_at FROM articles ORDER BY id")

    articles = fetch_all(conn, stmt, [])

    Exqlite.Sqlite3.release(conn, stmt)
    Exqlite.Sqlite3.close(conn)

    # Generate migration content
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d%H%M%S")
    filename = "priv/repo/migrations/#{timestamp}_seed_articles.exs"

    migration_content = generate_migration(articles)

    File.write!(filename, migration_content)
    IO.puts("Generated: #{filename}")
    IO.puts("Articles included: #{length(articles)}")
  end

  defp fetch_all(conn, stmt, acc) do
    case Exqlite.Sqlite3.step(conn, stmt) do
      {:row, row} ->
        [id, slug, title, author, content, tags, is_published, inserted_at, updated_at] = row
        article = %{
          id: id,
          slug: slug,
          title: title,
          author: author,
          content: content,
          tags: tags,
          is_published: is_published,
          inserted_at: inserted_at,
          updated_at: updated_at
        }
        fetch_all(conn, stmt, [article | acc])
      :done ->
        Enum.reverse(acc)
    end
  end

  defp generate_migration(articles) do
    content_functions = articles
    |> Enum.map(fn a ->
      "  defp content_#{a.id} do\n    ~S\"\"\"\n#{a.content}\n    \"\"\"\n  end\n"
    end)
    |> Enum.join("\n")

    article_entries = articles
    |> Enum.map(fn a ->
      """
            %{
              slug: "#{escape_string(a.slug)}",
              title: "#{escape_string(a.title)}",
              author: "#{escape_string(a.author)}",
              content: content_#{a.id}(),
              tags: #{inspect(a.tags)},
              is_published: #{if a.is_published == 1, do: 1, else: 0},
              inserted_at: {:placeholder, :now},
              updated_at: {:placeholder, :now}
            }\
      """
    end)
    |> Enum.join(",\n")

    slugs = articles |> Enum.map(& &1.slug) |> Enum.map(&"\"#{&1}\"") |> Enum.join(", ")

    """
    defmodule Gallformers.Repo.Migrations.SeedArticles do
      @moduledoc \"\"\"
      Seeds the articles table with initial reference articles.
      Only runs if the articles table is empty to avoid overwriting future edits.
      \"\"\"
      use Ecto.Migration
      import Ecto.Query

      def up do
        # Only insert if table is empty
        count = repo().one(from a in "articles", select: count(a.id))

        if count == 0 do
          now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

          articles = [
    #{article_entries}
          ]

          repo().insert_all("articles", articles, placeholders: %{now: now})
        end
      end

      def down do
        slugs = [#{slugs}]
        repo().delete_all(from a in "articles", where: a.slug in ^slugs)
      end

    #{content_functions}
    end
    """
  end

  defp escape_string(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
  end
end

GenerateArticlesSeedMigration.run()
