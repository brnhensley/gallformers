defmodule GallformersWeb.API.GlossaryController do
  @moduledoc """
  API controller for glossary endpoints.
  """

  use GallformersWeb, :controller

  alias Gallformers.Glossary

  @doc """
  GET /api/v2/glossary
  Lists all glossary entries with optional search and pagination.
  """
  def index(conn, params) do
    limit = parse_int(params["limit"])
    offset = parse_int(params["offset"]) || 0
    query = params["q"]

    {entries, total} =
      case {query, limit} do
        {nil, nil} ->
          all = Glossary.list_glossary()
          {all, length(all)}

        {nil, limit} ->
          all = Glossary.list_glossary()
          paginated = all |> Enum.drop(offset) |> Enum.take(limit)
          {paginated, length(all)}

        {query, nil} ->
          results = Glossary.search_glossary(query)
          {results, length(results)}

        {query, limit} ->
          all = Glossary.search_glossary(query)
          paginated = all |> Enum.drop(offset) |> Enum.take(limit)
          {paginated, length(all)}
      end

    json(conn, %{
      data: Enum.map(entries, &glossary_to_map/1),
      total: total,
      limit: limit,
      offset: offset
    })
  end

  @doc """
  GET /api/v2/glossary/:id
  Gets a single glossary entry by ID.
  """
  def show(conn, %{"id" => id}) do
    case parse_int(id) do
      nil ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid glossary ID"})

      id ->
        case Glossary.get_glossary(id) do
          nil ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "Glossary entry not found"})

          entry ->
            json(conn, glossary_to_map(entry))
        end
    end
  end

  @doc """
  GET /api/v2/glossary/by-word/:word
  Gets a glossary entry by word.
  """
  def by_word(conn, %{"word" => word}) do
    case Glossary.get_glossary_by_word(word) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Glossary entry not found"})

      entry ->
        json(conn, glossary_to_map(entry))
    end
  end

  # Private functions

  defp glossary_to_map(entry) do
    %{
      id: entry.id,
      word: entry.word,
      definition: entry.definition,
      urls: entry.urls
    }
  end

  defp parse_int(nil), do: nil

  defp parse_int(str) when is_binary(str) do
    case Integer.parse(str) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp parse_int(int) when is_integer(int), do: int
end
