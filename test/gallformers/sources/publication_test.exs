defmodule Gallformers.Sources.PublicationTest do
  use ExUnit.Case, async: true

  alias Gallformers.Sources.Publication
  alias Gallformers.Sources.Source

  describe "published_markdown_path/1" do
    test "builds a snake_case path under the public sources namespace" do
      source = %Source{id: 42, title: "Oaks & Their Galls"}

      assert Publication.published_markdown_path(source) ==
               "sources/42/oaks_their_galls.md"
    end

    test "truncates long filenames deterministically and preserves the markdown suffix" do
      source = %Source{id: 42, title: String.duplicate("A", 200)}
      path = Publication.published_markdown_path(source)

      assert path == "sources/42/#{String.duplicate("a", 120)}.md"
    end

    test "falls back to a source-id-based filename when normalization would be blank" do
      source = %Source{id: 55, title: "!!!"}

      assert Publication.published_markdown_path(source) == "sources/55/source_55.md"
    end
  end

  describe "published_markdown_url/1" do
    test "builds the public URL from the published markdown path" do
      source = %Source{id: 7, title: "Gall Paper"}

      assert Publication.published_markdown_url(source) ==
               "https://gallformers-images-us-east-1.s3.amazonaws.com/sources/7/gall_paper.md"
    end
  end
end
