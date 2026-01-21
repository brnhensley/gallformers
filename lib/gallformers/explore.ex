defmodule Gallformers.Explore do
  @moduledoc """
  The Explore context.

  Provides functions for building hierarchical tree data for browsing
  galls and hosts by taxonomic family.
  """

  import Ecto.Query
  alias Gallformers.Repo
  alias Gallformers.Species.{Gall, GallSpecies, Species}
  alias Gallformers.Taxonomy.Taxonomy

  @doc """
  Returns a hierarchical tree of gall species organized by Family → Genus → Species.

  Each node has:
  - key: unique identifier (string)
  - label: display text
  - url: navigation URL (only for species leaves)
  - nodes: child nodes (for families and genera)
  """
  @spec get_galls_tree() :: [map()]
  def get_galls_tree do
    get_species_tree("gall", false)
  end

  @doc """
  Returns a hierarchical tree of undescribed gall species.
  """
  @spec get_undescribed_tree() :: [map()]
  def get_undescribed_tree do
    get_species_tree("gall", true)
  end

  @doc """
  Returns a hierarchical tree of host species organized by Family → Genus → Species.
  """
  @spec get_hosts_tree() :: [map()]
  def get_hosts_tree do
    get_species_tree("plant", false)
  end

  defp get_species_tree(taxoncode, undescribed_only) do
    rows = fetch_tree_data(taxoncode, undescribed_only)
    build_tree(rows, taxoncode)
  end

  defp fetch_tree_data("gall", undescribed_only) do
    base_query =
      from f in Taxonomy,
        join: g in Taxonomy,
        on: g.parent_id == f.id and g.type == "genus",
        join: st in "speciestaxonomy",
        on: st.taxonomy_id == g.id,
        join: s in Species,
        on: s.id == st.species_id,
        join: gs in GallSpecies,
        on: gs.species_id == s.id,
        join: gall in Gall,
        on: gs.gall_id == gall.id,
        where: f.type == "family" and f.description != "Plant" and s.taxoncode == "gall",
        order_by: [f.name, g.name, s.name],
        select: %{
          family_id: f.id,
          family_name: f.name,
          family_description: f.description,
          genus_id: g.id,
          genus_name: g.name,
          genus_description: g.description,
          species_id: s.id,
          species_name: s.name,
          undescribed: gall.undescribed
        }

    query =
      if undescribed_only do
        from [f, g, st, s, gs, gall] in base_query,
          where: gall.undescribed == true
      else
        base_query
      end

    Repo.all(query)
  end

  defp fetch_tree_data("plant", _undescribed_only) do
    from(f in Taxonomy,
      join: g in Taxonomy,
      on: g.parent_id == f.id and g.type == "genus",
      join: st in "speciestaxonomy",
      on: st.taxonomy_id == g.id,
      join: s in Species,
      on: s.id == st.species_id,
      where: f.type == "family" and f.description == "Plant" and s.taxoncode == "plant",
      order_by: [f.name, g.name, s.name],
      select: %{
        family_id: f.id,
        family_name: f.name,
        family_description: f.description,
        genus_id: g.id,
        genus_name: g.name,
        genus_description: g.description,
        species_id: s.id,
        species_name: s.name,
        undescribed: false
      }
    )
    |> Repo.all()
  end

  defp build_tree(rows, taxoncode) do
    url_prefix = if taxoncode == "plant", do: "/host/", else: "/gall/"

    # Group by family, then genus, then species
    # Using maps to track unique entries and maintain order
    families_map = %{}
    families_order = []

    {families_map, families_order} =
      Enum.reduce(rows, {families_map, families_order}, fn row, {fam_map, fam_order} ->
        family_key = row.family_id

        {fam_map, fam_order} =
          if Map.has_key?(fam_map, family_key) do
            {fam_map, fam_order}
          else
            family_entry = %{
              id: row.family_id,
              name: row.family_name,
              description: row.family_description,
              genera: %{},
              genera_order: []
            }

            {Map.put(fam_map, family_key, family_entry), fam_order ++ [family_key]}
          end

        # Update genera within family
        family = Map.get(fam_map, family_key)
        genus_key = row.genus_id

        {genera_map, genera_order} =
          if Map.has_key?(family.genera, genus_key) do
            {family.genera, family.genera_order}
          else
            genus_entry = %{
              id: row.genus_id,
              name: row.genus_name,
              description: row.genus_description,
              species: %{},
              species_order: []
            }

            {Map.put(family.genera, genus_key, genus_entry), family.genera_order ++ [genus_key]}
          end

        # Update species within genus
        genus = Map.get(genera_map, genus_key)
        species_key = row.species_id

        {species_map, species_order} =
          if Map.has_key?(genus.species, species_key) do
            {genus.species, genus.species_order}
          else
            species_entry = %{
              id: row.species_id,
              name: row.species_name
            }

            {Map.put(genus.species, species_key, species_entry),
             genus.species_order ++ [species_key]}
          end

        genus = %{genus | species: species_map, species_order: species_order}
        genera_map = Map.put(genera_map, genus_key, genus)
        family = %{family | genera: genera_map, genera_order: genera_order}
        fam_map = Map.put(fam_map, family_key, family)

        {fam_map, fam_order}
      end)

    # Convert to tree nodes
    Enum.map(families_order, fn family_key ->
      family = Map.get(families_map, family_key)
      genus_nodes = build_genus_nodes(family, url_prefix)

      %{
        key: "f-#{family.id}",
        label: format_label(family.name, family.description),
        nodes: genus_nodes
      }
    end)
  end

  defp build_genus_nodes(family, url_prefix) do
    Enum.map(family.genera_order, fn genus_key ->
      genus = Map.get(family.genera, genus_key)
      species_nodes = build_species_nodes(genus, url_prefix)

      %{
        key: "g-#{genus.id}",
        label: format_label(genus.name, genus.description),
        nodes: species_nodes
      }
    end)
  end

  defp build_species_nodes(genus, url_prefix) do
    Enum.map(genus.species_order, fn species_key ->
      species = Map.get(genus.species, species_key)

      %{
        key: "s-#{species.id}",
        label: species.name,
        url: "#{url_prefix}#{species.id}"
      }
    end)
  end

  defp format_label(name, nil), do: name
  defp format_label(name, ""), do: name
  defp format_label(name, "Plant"), do: name
  defp format_label(name, description), do: "#{name} (#{description})"
end
