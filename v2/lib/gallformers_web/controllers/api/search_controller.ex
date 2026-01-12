defmodule GallformersWeb.API.SearchController do
  @moduledoc """
  API controller for global search endpoint.
  """

  use GallformersWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Gallformers.Search
  alias GallformersWeb.Schemas

  tags(["Search"])

  operation(:search,
    summary: "Global search",
    description: "Performs a global search across all entity types",
    parameters: [
      q: [in: :query, type: :string, description: "Search query", required: true]
    ],
    responses: [
      ok: {"Search results", "application/json", Schemas.SearchResults}
    ]
  )

  @doc """
  GET /api/v2/search?q=query
  Performs a global search across all entity types.
  """
  def search(conn, %{"q" => query}) when is_binary(query) and query != "" do
    results = Search.global_search(query)
    json(conn, results)
  end

  def search(conn, _params) do
    json(conn, Search.empty_results())
  end
end
