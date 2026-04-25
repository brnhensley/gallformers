defmodule Gallformers.Sources.Publication do
  @moduledoc """
  Public published-source path and URL rules.
  """

  alias Gallformers.Sources.Source
  alias Gallformers.Storage.SourceArtifacts

  @published_sources_prefix "sources"
  @max_filename_base_length 120

  @doc """
  Returns the public `sources/{id}` prefix for a source.
  """
  @spec source_prefix(integer()) :: String.t()
  def source_prefix(source_id) when is_integer(source_id) do
    Path.join([@published_sources_prefix, Integer.to_string(source_id)])
  end

  @doc """
  Returns the canonical public markdown path for a published source.
  """
  @spec published_markdown_path(Source.t()) :: String.t()
  def published_markdown_path(%Source{id: source_id, title: title}) when is_integer(source_id) do
    Path.join([source_prefix(source_id), markdown_filename(source_id, title)])
  end

  @doc """
  Returns the public URL for a published source markdown file.
  """
  @spec published_markdown_url(Source.t()) :: String.t()
  def published_markdown_url(%Source{} = source) do
    source
    |> published_markdown_path()
    |> SourceArtifacts.public_url()
  end

  defp markdown_filename(source_id, title) do
    base_name =
      title
      |> normalize_title()
      |> truncate_base_name()
      |> fallback_base_name(source_id)

    "#{base_name}.md"
  end

  defp normalize_title(title) when is_binary(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^\p{L}\p{N}\s_-]/u, "")
    |> String.replace(~r/[\s-]+/u, "_")
    |> String.replace(~r/_+/, "_")
    |> String.trim("_")
  end

  defp normalize_title(_title), do: ""

  defp truncate_base_name(base_name) do
    base_name
    |> String.slice(0, @max_filename_base_length)
    |> String.trim_trailing("_")
  end

  defp fallback_base_name("", source_id), do: "source_#{source_id}"
  defp fallback_base_name(base_name, _source_id), do: base_name
end
