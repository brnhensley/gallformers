defmodule GallformersWeb.RobotsController do
  @moduledoc """
  Controller for serving robots.txt.

  Allows crawling of public pages while disallowing admin and API routes.
  """
  use GallformersWeb, :controller

  @doc """
  Renders the robots.txt file.
  """
  def index(conn, _params) do
    robots_txt = """
    # Gallformers Robots.txt
    # https://gallformers.org

    User-agent: *

    # Allow all public pages
    Allow: /

    # Disallow admin routes (if any are added in the future)
    Disallow: /admin/
    Disallow: /admin

    # Allow API documentation for discovery by AI agents
    Allow: /api/docs/

    # Disallow other API routes (use the API programmatically, not for crawling)
    Disallow: /api/
    Disallow: /api

    # Disallow dev routes
    Disallow: /dev/
    Disallow: /dev

    # Sitemap location
    Sitemap: https://gallformers.org/sitemap.xml
    """

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, robots_txt)
  end
end
