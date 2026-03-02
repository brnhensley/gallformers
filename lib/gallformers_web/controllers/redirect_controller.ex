defmodule GallformersWeb.RedirectController do
  @moduledoc """
  Handles 301 redirects from legacy URLs to their new canonical locations.
  """
  use GallformersWeb, :controller

  @doc """
  Redirects /refindex to /articles
  """
  def articles(conn, _params) do
    # Preserve any query params (e.g., ?tag=...)
    query_string = conn.query_string

    path =
      if query_string == "" do
        "/articles"
      else
        "/articles?#{query_string}"
      end

    conn
    |> put_status(:moved_permanently)
    |> redirect(to: path)
  end

  @doc """
  Redirects /ref/:slug to /articles/:slug
  """
  def article(conn, %{"slug" => slug}) do
    conn
    |> put_status(:moved_permanently)
    |> redirect(to: "/articles/#{slug}")
  end

  @doc """
  Redirects old /taxonomy/:id URLs to name-based routes.

  Maps each taxonomy type to its canonical URL:
  - family → /family/:name
  - genus → /genus/:name
  - section → /section/:name
  - intermediate → /:rank/:name (e.g., /subfamily/Cynipinae)
  """
  def taxonomy(conn, %{"id" => id_str}) do
    case Integer.parse(id_str) do
      {id, ""} ->
        case Gallformers.Taxonomy.get_taxonomy(id) do
          nil ->
            conn
            |> put_status(:not_found)
            |> put_view(GallformersWeb.ErrorHTML)
            |> render(:"404")

          %{type: "intermediate", rank: rank, name: name} when rank not in [nil, ""] ->
            conn
            |> put_status(:moved_permanently)
            |> redirect(to: "/#{String.downcase(rank)}/#{name}")

          %{type: type, name: name} when type in ["family", "genus", "section"] ->
            conn
            |> put_status(:moved_permanently)
            |> redirect(to: "/#{type}/#{name}")

          _ ->
            conn
            |> put_status(:not_found)
            |> put_view(GallformersWeb.ErrorHTML)
            |> render(:"404")
        end

      _ ->
        conn
        |> put_status(:not_found)
        |> put_view(GallformersWeb.ErrorHTML)
        |> render(:"404")
    end
  end

  @doc """
  Redirects /explore to the appropriate new browse page.

  Maps old tab params to new routes:
  - /explore or /explore?tab=galls -> /galls
  - /explore?tab=undescribed -> /galls
  - /explore?tab=hosts -> /hosts
  - /explore?tab=places -> /places
  """
  def explore(conn, params) do
    path =
      case params["tab"] do
        "hosts" -> "/hosts"
        "places" -> "/places"
        _other -> "/galls"
      end

    conn
    |> put_status(:moved_permanently)
    |> redirect(to: path)
  end
end
