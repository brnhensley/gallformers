defmodule GallformersWeb.API.ExploreController do
  @moduledoc """
  API controller for the explore endpoint.

  Returns hierarchical tree data for browsing galls, undescribed galls, and hosts.
  """

  use GallformersWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import Ecto.Query

  alias Gallformers.Repo
  alias Gallformers.Species.{Gall, GallSpecies}
  alias Gallformers.Species.Species, as: SpeciesSchema
  alias Gallformers.Taxonomy.Taxonomy
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
    galls_tree = build_galls_tree(false)
    undescribed_tree = build_galls_tree(true)
    hosts_tree = build_hosts_tree()

    json(conn, %{
      galls: galls_tree,
      undescribed: undescribed_tree,
      hosts: hosts_tree
    })
  end

  # Private functions

  defp build_galls_tree(undescribed_only) do
    galls_query = build_galls_query(undescribed_only)
    galls = Repo.all(galls_query)
    build_family_tree(galls, "gall")
  end

  defp build_galls_query(undescribed_only) do
    base_query =
      from(s in SpeciesSchema,
        join: gs in GallSpecies,
        on: gs.species_id == s.id,
        join: g in Gall,
        on: gs.gall_id == g.id,
        join: st in "speciestaxonomy",
        on: st.species_id == s.id,
        join: genus in Taxonomy,
        on: st.taxonomy_id == genus.id and genus.type == "genus",
        left_join: family in Taxonomy,
        on: genus.parent_id == family.id and family.type == "family",
        where: s.taxoncode == "gall",
        select: %{
          id: s.id,
          name: s.name,
          undescribed: g.undescribed,
          genus_id: genus.id,
          genus_name: genus.name,
          family_id: family.id,
          family_name: family.name
        }
      )

    if undescribed_only do
      from([s, gs, g, st, genus, family] in base_query, where: g.undescribed == true)
    else
      base_query
    end
  end

  defp build_hosts_tree do
    hosts = fetch_hosts_with_taxonomy()
    build_family_tree(hosts, "host")
  end

  defp fetch_hosts_with_taxonomy do
    from(s in SpeciesSchema,
      join: st in "speciestaxonomy",
      on: st.species_id == s.id,
      join: genus in Taxonomy,
      on: st.taxonomy_id == genus.id and genus.type == "genus",
      left_join: family in Taxonomy,
      on: genus.parent_id == family.id and family.type == "family",
      where: s.taxoncode == "plant",
      select: %{
        id: s.id,
        name: s.name,
        genus_id: genus.id,
        genus_name: genus.name,
        family_id: family.id,
        family_name: family.name
      }
    )
    |> Repo.all()
  end

  defp build_family_tree(species_list, entity_type) do
    species_list
    |> Enum.group_by(fn s -> {s.family_id, s.family_name} end)
    |> Enum.sort_by(fn {{_, name}, _} -> name || "" end)
    |> Enum.map(&build_family_node(&1, entity_type))
  end

  defp build_family_node({{family_id, family_name}, family_species}, entity_type) do
    genera = build_genera_nodes(family_species, entity_type)

    %{
      key: "family-#{family_id}",
      label: family_name || "Unknown Family",
      url: if(family_id, do: "/family/#{family_id}", else: nil),
      nodes: genera
    }
  end

  defp build_genera_nodes(species_list, entity_type) do
    species_list
    |> Enum.group_by(fn s -> {s.genus_id, s.genus_name} end)
    |> Enum.sort_by(fn {{_, name}, _} -> name end)
    |> Enum.map(&build_genus_node(&1, entity_type))
  end

  defp build_genus_node({{genus_id, genus_name}, genus_species}, entity_type) do
    species_nodes = build_species_nodes(genus_species, entity_type)

    %{
      key: "genus-#{genus_id}",
      label: genus_name,
      url: "/genus/#{genus_id}",
      nodes: species_nodes
    }
  end

  defp build_species_nodes(species_list, entity_type) do
    url_prefix = if entity_type == "gall", do: "/gall/", else: "/host/"

    species_list
    |> Enum.sort_by(& &1.name)
    |> Enum.map(fn s ->
      %{
        key: "species-#{s.id}",
        label: s.name,
        url: "#{url_prefix}#{s.id}"
      }
    end)
  end
end
