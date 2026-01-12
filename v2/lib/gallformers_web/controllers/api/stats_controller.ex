defmodule GallformersWeb.API.StatsController do
  @moduledoc """
  API controller for stats endpoint.

  Returns summary statistics about the database.
  """

  use GallformersWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import Ecto.Query

  alias Gallformers.{Glossary, Hosts, Repo, Sources, Species}
  alias Gallformers.Species.{Gall, GallSpecies}
  alias Gallformers.Species.Species, as: SpeciesSchema
  alias GallformersWeb.Schemas

  tags ["Stats"]

  operation :index,
    summary: "Get statistics",
    description: "Returns summary statistics about the database",
    responses: [
      ok: {"Statistics", "application/json", Schemas.Stats}
    ]

  @doc """
  GET /api/v2/stats
  Returns summary statistics.
  """
  def index(conn, _params) do
    stats = %{
      galls: Species.count_galls(),
      hosts: Hosts.count_hosts(),
      sources: Sources.count_sources(),
      glossary: Glossary.count_glossary(),
      undescribed_galls: count_undescribed_galls(),
      images: count_images()
    }

    json(conn, stats)
  end

  defp count_undescribed_galls do
    from(s in SpeciesSchema,
      join: gs in GallSpecies,
      on: gs.species_id == s.id,
      join: g in Gall,
      on: gs.gall_id == g.id,
      where: s.taxoncode == "gall" and g.undescribed == true,
      select: count(s.id)
    )
    |> Repo.one()
  end

  defp count_images do
    alias Gallformers.Species.Image

    from(i in Image, select: count(i.id))
    |> Repo.one()
  end
end
