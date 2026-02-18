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

    # --- Block SEO crawlers that provide no value to the site ---

    User-agent: AhrefsBot
    Disallow: /

    User-agent: SemrushBot
    Disallow: /

    User-agent: SERankingBacklinksBot
    Disallow: /

    User-agent: MJ12bot
    Disallow: /

    User-agent: DotBot
    Disallow: /

    # --- Default rules for all other crawlers ---

    User-agent: *
    Crawl-delay: 10

    # Interactive tools - not useful for indexing
    Disallow: /id
    Disallow: /globalsearch

    # Admin area
    Disallow: /admin/
    Disallow: /admin

    # Allow API documentation for discovery by AI agents
    Allow: /api/docs/

    # API - use programmatically, not for crawling
    Disallow: /api/
    Disallow: /api

    # Auth flows
    Disallow: /auth

    # Health checks
    Disallow: /health

    # Dev routes
    Disallow: /dev/
    Disallow: /dev

    # Allow everything else (galls, hosts, species, sources, places, etc.)
    Allow: /

    # Sitemap location
    Sitemap: https://gallformers.org/sitemap.xml
    """

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, robots_txt)
  end
end
