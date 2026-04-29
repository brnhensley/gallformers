defmodule Gallformers.IngestionPipeline.DuplicateSignals do
  @moduledoc """
  Shared normalization helpers for duplicate-detection metadata signals.
  """

  @spec signal_attrs(map(), map()) :: map()
  def signal_attrs(attrs, extra_attrs \\ %{}) when is_map(attrs) and is_map(extra_attrs) do
    title = fetch_attr(attrs, [:title, "title"])
    authors = normalize_authors(fetch_attr(attrs, [:authors, "authors"], []))
    normalized_title = normalize_title(title)
    doi = fetch_attr(attrs, [:doi, "doi"])

    %{
      title: title,
      normalized_title: normalized_title,
      title_fingerprint: title_fingerprint(normalized_title),
      authors: authors,
      author_fingerprint: author_fingerprint(authors),
      publication_year: fetch_attr(attrs, [:publication_year, :year, "publication_year", "year"]),
      doi: doi,
      normalized_doi: normalize_doi(doi)
    }
    |> Map.merge(extra_attrs)
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  @spec normalize_doi(String.t() | nil) :: String.t() | nil
  def normalize_doi(nil), do: nil

  def normalize_doi(doi) do
    doi
    |> String.downcase()
    |> String.trim()
    |> String.trim_leading("doi:")
    |> String.trim()
    |> String.trim_trailing(".")
    |> String.trim_trailing(",")
    |> String.trim_trailing(";")
  end

  @spec normalize_title(String.t() | nil) :: String.t() | nil
  def normalize_title(nil), do: nil

  def normalize_title(title) do
    title
    |> String.downcase()
    |> String.trim()
    |> String.replace(~r/[^\p{L}\p{N}\s]/u, " ")
    |> String.replace(~r/\s+/u, " ")
    |> String.trim_trailing(".")
    |> String.trim_trailing(",")
    |> String.trim_trailing(";")
    |> String.trim_trailing(":")
  end

  @spec title_fingerprint(String.t() | nil) :: String.t() | nil
  def title_fingerprint(nil), do: nil

  def title_fingerprint(normalized_title) do
    normalized_title
    |> String.split(" ", trim: true)
    |> Enum.reject(&(&1 in ~w(a an and the of in on for to by with)))
    |> case do
      [] -> nil
      tokens -> Enum.join(tokens, "_")
    end
  end

  @spec author_fingerprint([String.t()]) :: String.t() | nil
  def author_fingerprint([]), do: nil

  def author_fingerprint(authors) when is_list(authors) do
    authors
    |> Enum.map(&author_token/1)
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> nil
      tokens -> Enum.join(tokens, "_")
    end
  end

  defp normalize_authors(nil), do: []

  defp normalize_authors(authors) when is_list(authors) do
    authors
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp fetch_attr(attrs, keys, default \\ nil)
  defp fetch_attr(_attrs, [], default), do: default

  defp fetch_attr(attrs, [key | rest], default) do
    case Map.fetch(attrs, key) do
      {:ok, value} -> value
      :error -> fetch_attr(attrs, rest, default)
    end
  end

  defp author_token(author) do
    author = String.trim(author)

    cond do
      author == "" ->
        nil

      String.contains?(author, ",") ->
        author
        |> String.split(",", parts: 2)
        |> List.first()
        |> normalize_author_part()

      true ->
        author
        |> String.split(~r/\s+/, trim: true)
        |> List.last()
        |> normalize_author_part()
    end
  end

  defp normalize_author_part(nil), do: nil

  defp normalize_author_part(part) do
    part
    |> String.downcase()
    |> String.replace(~r/[^\p{L}\p{N}]/u, "")
    |> case do
      "" -> nil
      normalized -> normalized
    end
  end
end
