defmodule GallformersWeb.API.SourceController do
  @moduledoc """
  API controller for source endpoints.
  """

  use GallformersWeb, :controller

  alias Gallformers.Sources

  @doc """
  GET /api/v2/sources
  Lists all sources with optional search and pagination.
  """
  def index(conn, params) do
    limit = parse_int(params["limit"])
    offset = parse_int(params["offset"]) || 0
    query = params["q"]

    {sources, total} =
      case {query, limit} do
        {nil, nil} ->
          all = Sources.list_sources()
          {all, length(all)}

        {nil, limit} ->
          total = Sources.count_sources()
          paginated = Sources.list_sources_paginated(limit, offset)
          {paginated, total}

        {query, nil} ->
          results = Sources.search_sources(query)
          {results, length(results)}

        {query, limit} ->
          all = Sources.search_sources(query)
          paginated = all |> Enum.drop(offset) |> Enum.take(limit)
          {paginated, length(all)}
      end

    json(conn, %{
      data: Enum.map(sources, &source_to_map/1),
      total: total,
      limit: limit,
      offset: offset
    })
  end

  @doc """
  GET /api/v2/sources/:id
  Gets a single source by ID with its species.
  """
  def show(conn, %{"id" => id}) do
    case parse_int(id) do
      nil ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid source ID"})

      id ->
        case Sources.get_source(id) do
          nil ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "Source not found"})

          source ->
            species = Sources.get_species_for_source(id)

            json(conn, %{
              id: source.id,
              title: source.title,
              author: source.author,
              pubyear: source.pubyear,
              link: source.link,
              citation: source.citation,
              datacomplete: source.datacomplete,
              species:
                Enum.map(species, fn s ->
                  %{
                    id: s.id,
                    name: s.name,
                    taxoncode: s.taxoncode,
                    description: s.description,
                    externallink: s.externallink
                  }
                end)
            })
        end
    end
  end

  # Private functions

  defp source_to_map(source) do
    %{
      id: source.id,
      title: source.title,
      author: source.author,
      pubyear: source.pubyear,
      link: source.link,
      citation: source.citation,
      datacomplete: source.datacomplete
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
