defmodule GallformersWeb.ApiSpec do
  @moduledoc """
  OpenAPI specification for the Gallformers API.
  """

  alias OpenApiSpex.{Info, OpenApi, Paths, Server}

  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      info: %Info{
        title: "Gallformers API",
        version: "2.0.0",
        description: """
        Public API for accessing Gallformers data.

        The Gallformers API provides read-only access to:
        - Galls (plant growths caused by insects and other organisms)
        - Host plants
        - Taxonomy (families, genera, sections)
        - Sources (scientific references)
        - Glossary terms
        - Geographic places
        - Search and explore functionality
        """
      },
      servers: [
        %Server{url: "https://gallformers.org", description: "Production"},
        %Server{url: "http://localhost:4000", description: "Development"}
      ],
      paths: Paths.from_router(GallformersWeb.Router)
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
