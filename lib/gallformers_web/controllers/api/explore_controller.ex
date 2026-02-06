defmodule GallformersWeb.API.ExploreController do
  @moduledoc """
  API controller for the explore endpoint.

  Returns hierarchical tree data for browsing galls, undescribed galls, and hosts.
  """

  use GallformersWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Gallformers.Galls
  alias Gallformers.Plants
  alias GallformersWeb.Schemas

  tags(["Explore"])

  operation(:explore,
    summary: "Explore tree data",
    description:
      "Returns hierarchical tree data for browsing galls, undescribed galls, and hosts",
    responses: [
      ok: {"Explore tree data", "application/json", Schemas.ExploreResponse}
    ]
  )

  @doc """
  GET /api/v2/explore
  Returns three tree structures: galls, undescribed, and hosts.
  """
  def explore(conn, _params) do
    opts = [key_style: :long]

    json(conn, %{
      galls: Galls.get_galls_tree(opts),
      undescribed: Galls.get_undescribed_tree(opts),
      hosts: Plants.get_hosts_tree(opts)
    })
  end
end
