defmodule GallformersWeb.API.SearchController do
  @moduledoc """
  API controller for global search endpoint.
  """

  use GallformersWeb, :controller

  alias Gallformers.Search

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
