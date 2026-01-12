defmodule Gallformers.IDTool do
  @moduledoc """
  The IDTool context.

  Provides functions for the gall identification tool, which allows users
  to filter galls by various characteristics (host, location, color, shape, etc.).
  """

  import Ecto.Query

  alias Gallformers.FilterFields.{
    Alignment,
    Cells,
    Color,
    Form,
    Location,
    Season,
    Shape,
    Texture,
    Walls
  }

  alias Gallformers.Hosts.Host
  alias Gallformers.Repo
  alias Gallformers.Species
  alias Gallformers.Species.{Gall, GallSpecies, Image}
  alias Gallformers.Species.Species, as: SpeciesSchema
  alias Gallformers.Taxonomy.Taxonomy

  @doc """
  Returns all filter field options for the ID tool.

  Returns a map with all available filter options.
  """
  @spec get_filter_options() :: map()
  def get_filter_options do
    %{
      alignments: list_alignments(),
      cells: list_cells(),
      colors: list_colors(),
      forms: list_forms(),
      locations: list_locations(),
      seasons: list_seasons(),
      shapes: list_shapes(),
      textures: list_textures(),
      walls: list_walls()
    }
  end

  @doc """
  Filters galls based on the provided criteria.

  Accepts a map with optional keys:
    - :host_ids - list of host species IDs
    - :location_ids - list of location IDs
    - :color_ids - list of color IDs
    - :shape_ids - list of shape IDs
    - :texture_ids - list of texture IDs
    - :alignment_ids - list of alignment IDs
    - :cells_ids - list of cells IDs
    - :walls_ids - list of walls IDs
    - :form_ids - list of form IDs
    - :season_ids - list of season IDs
    - :detachable - 0, 1, or 2 (unknown)
    - :place_codes - list of place codes (states/provinces)

  Returns a list of matching gall species.
  """
  @spec filter_galls(map()) :: [map()]
  def filter_galls(filters \\ %{}) do
    base_query()
    |> apply_host_filter(filters[:host_ids])
    |> apply_genus_filter(filters[:genus_id])
    |> apply_family_filter(filters[:family_id])
    |> apply_location_filter(filters[:location_ids])
    |> apply_color_filter(filters[:color_ids])
    |> apply_shape_filter(filters[:shape_ids])
    |> apply_texture_filter(filters[:texture_ids])
    |> apply_alignment_filter(filters[:alignment_ids])
    |> apply_cells_filter(filters[:cells_ids])
    |> apply_walls_filter(filters[:walls_ids])
    |> apply_form_filter(filters[:form_ids])
    |> apply_season_filter(filters[:season_ids])
    |> apply_detachable_filter(filters[:detachable])
    |> apply_place_filter(filters[:place_codes])
    |> apply_undescribed_filter(filters[:undescribed])
    |> select_gall_fields()
    |> Repo.all()
    |> attach_images()
  end

  @doc """
  Returns the count of galls matching the filters.
  """
  @spec count_filtered_galls(map()) :: integer()
  def count_filtered_galls(filters \\ %{}) do
    base_query()
    |> apply_host_filter(filters[:host_ids])
    |> apply_location_filter(filters[:location_ids])
    |> apply_color_filter(filters[:color_ids])
    |> apply_shape_filter(filters[:shape_ids])
    |> apply_texture_filter(filters[:texture_ids])
    |> apply_alignment_filter(filters[:alignment_ids])
    |> apply_cells_filter(filters[:cells_ids])
    |> apply_walls_filter(filters[:walls_ids])
    |> apply_form_filter(filters[:form_ids])
    |> apply_season_filter(filters[:season_ids])
    |> apply_detachable_filter(filters[:detachable])
    |> apply_place_filter(filters[:place_codes])
    |> select([s, _gs, _g], count(s.id, :distinct))
    |> Repo.one()
  end

  @doc """
  Gets hosts that have galls matching the filters.

  Used to show which hosts are available based on current filter selections.
  """
  @spec get_hosts_for_filters(map()) :: [map()]
  def get_hosts_for_filters(filters \\ %{}) do
    # Get gall species IDs matching the filters
    gall_ids =
      base_query()
      |> apply_location_filter(filters[:location_ids])
      |> apply_color_filter(filters[:color_ids])
      |> apply_shape_filter(filters[:shape_ids])
      |> apply_texture_filter(filters[:texture_ids])
      |> apply_alignment_filter(filters[:alignment_ids])
      |> apply_cells_filter(filters[:cells_ids])
      |> apply_walls_filter(filters[:walls_ids])
      |> apply_form_filter(filters[:form_ids])
      |> apply_season_filter(filters[:season_ids])
      |> apply_detachable_filter(filters[:detachable])
      |> apply_place_filter(filters[:place_codes])
      |> select([s, _gs, _g], s.id)
      |> Repo.all()

    if Enum.empty?(gall_ids) do
      []
    else
      from(h in Host,
        join: host_species in Species,
        on: h.host_species_id == host_species.id,
        where: h.gall_species_id in ^gall_ids,
        group_by: [host_species.id, host_species.name],
        order_by: host_species.name,
        select: %{
          id: host_species.id,
          name: host_species.name,
          count: count(h.id)
        }
      )
      |> Repo.all()
    end
  end

  # Filter field list functions
  @spec list_alignments() :: [Alignment.t()]
  def list_alignments, do: Repo.all(from a in Alignment, order_by: a.alignment)

  @spec list_cells() :: [Cells.t()]
  def list_cells, do: Repo.all(from c in Cells, order_by: c.cells)

  @spec list_colors() :: [Color.t()]
  def list_colors, do: Repo.all(from c in Color, order_by: c.color)

  @spec list_forms() :: [Form.t()]
  def list_forms, do: Repo.all(from f in Form, order_by: f.form)

  @spec list_locations() :: [Location.t()]
  def list_locations, do: Repo.all(from l in Location, order_by: l.location)

  @spec list_seasons() :: [Season.t()]
  def list_seasons, do: Repo.all(from s in Season, order_by: s.season)

  @spec list_shapes() :: [Shape.t()]
  def list_shapes, do: Repo.all(from s in Shape, order_by: s.shape)

  @spec list_textures() :: [Texture.t()]
  def list_textures, do: Repo.all(from t in Texture, order_by: t.texture)

  @spec list_walls() :: [Walls.t()]
  def list_walls, do: Repo.all(from w in Walls, order_by: w.walls)

  # Private query building functions

  defp base_query do
    from s in SpeciesSchema,
      join: gs in GallSpecies,
      on: gs.species_id == s.id,
      join: g in Gall,
      on: gs.gall_id == g.id,
      where: s.taxoncode == "gall",
      distinct: true
  end

  defp select_gall_fields(query) do
    from [s, gs, g] in query,
      order_by: s.name,
      select: %{
        id: s.id,
        name: s.name,
        gall_id: g.id,
        undescribed: g.undescribed,
        detachable: g.detachable
      }
  end

  defp apply_host_filter(query, nil), do: query
  defp apply_host_filter(query, []), do: query

  defp apply_host_filter(query, host_ids) do
    from [s, _gs, _g] in query,
      join: h in Host,
      on: h.gall_species_id == s.id,
      where: h.host_species_id in ^host_ids
  end

  defp apply_location_filter(query, nil), do: query
  defp apply_location_filter(query, []), do: query

  defp apply_location_filter(query, location_ids) do
    from [s, _gs, g] in query,
      join: gl in "galllocation",
      on: gl.gall_id == g.id,
      where: gl.location_id in ^location_ids
  end

  defp apply_color_filter(query, nil), do: query
  defp apply_color_filter(query, []), do: query

  defp apply_color_filter(query, color_ids) do
    from [s, _gs, g] in query,
      join: gc in "gallcolor",
      on: gc.gall_id == g.id,
      where: gc.color_id in ^color_ids
  end

  defp apply_shape_filter(query, nil), do: query
  defp apply_shape_filter(query, []), do: query

  defp apply_shape_filter(query, shape_ids) do
    from [s, _gs, g] in query,
      join: gsh in "gallshape",
      on: gsh.gall_id == g.id,
      where: gsh.shape_id in ^shape_ids
  end

  defp apply_texture_filter(query, nil), do: query
  defp apply_texture_filter(query, []), do: query

  defp apply_texture_filter(query, texture_ids) do
    from [s, _gs, g] in query,
      join: gt in "galltexture",
      on: gt.gall_id == g.id,
      where: gt.texture_id in ^texture_ids
  end

  defp apply_alignment_filter(query, nil), do: query
  defp apply_alignment_filter(query, []), do: query

  defp apply_alignment_filter(query, alignment_ids) do
    from [s, _gs, g] in query,
      join: ga in "gallalignment",
      on: ga.gall_id == g.id,
      where: ga.alignment_id in ^alignment_ids
  end

  defp apply_cells_filter(query, nil), do: query
  defp apply_cells_filter(query, []), do: query

  defp apply_cells_filter(query, cells_ids) do
    from [s, _gs, g] in query,
      join: gc in "gallcells",
      on: gc.gall_id == g.id,
      where: gc.cells_id in ^cells_ids
  end

  defp apply_walls_filter(query, nil), do: query
  defp apply_walls_filter(query, []), do: query

  defp apply_walls_filter(query, walls_ids) do
    from [s, _gs, g] in query,
      join: gw in "gallwalls",
      on: gw.gall_id == g.id,
      where: gw.walls_id in ^walls_ids
  end

  defp apply_form_filter(query, nil), do: query
  defp apply_form_filter(query, []), do: query

  defp apply_form_filter(query, form_ids) do
    from [s, _gs, g] in query,
      join: gf in "gallform",
      on: gf.gall_id == g.id,
      where: gf.form_id in ^form_ids
  end

  defp apply_season_filter(query, nil), do: query
  defp apply_season_filter(query, []), do: query

  defp apply_season_filter(query, season_ids) do
    from [s, _gs, g] in query,
      join: gse in "gallseason",
      on: gse.gall_id == g.id,
      where: gse.season_id in ^season_ids
  end

  defp apply_detachable_filter(query, nil), do: query
  # 2 = unknown/any
  defp apply_detachable_filter(query, 2), do: query

  defp apply_detachable_filter(query, detachable) do
    from [s, _gs, g] in query,
      where: g.detachable == ^detachable
  end

  defp apply_place_filter(query, nil), do: query
  defp apply_place_filter(query, []), do: query

  defp apply_place_filter(query, place_codes) do
    # Filter by places where host plants are found, excluding explicit exclusions
    from [s, _gs, _g] in query,
      join: h in Host,
      on: h.gall_species_id == s.id,
      join: sp in "speciesplace",
      on: sp.species_id == h.host_species_id,
      join: p in "place",
      on: sp.place_id == p.id,
      where: p.code in ^place_codes,
      # Exclude galls that are explicitly marked as not in these places
      where:
        s.id not in subquery(
          from sp2 in "speciesplace",
            join: p2 in "place",
            on: sp2.place_id == p2.id,
            where: p2.code in ^place_codes,
            select: sp2.species_id
        )
  end

  defp apply_genus_filter(query, nil), do: query

  defp apply_genus_filter(query, genus_id) do
    from [s, _gs, _g] in query,
      join: st in "speciestaxonomy",
      on: st.species_id == s.id,
      where: st.taxonomy_id == ^genus_id
  end

  defp apply_family_filter(query, nil), do: query

  defp apply_family_filter(query, family_id) do
    from [s, _gs, _g] in query,
      join: st in "speciestaxonomy",
      on: st.species_id == s.id,
      join: t in Taxonomy,
      on: st.taxonomy_id == t.id,
      where: t.parent_id == ^family_id
  end

  defp apply_undescribed_filter(query, nil), do: query
  defp apply_undescribed_filter(query, false), do: query

  defp apply_undescribed_filter(query, true) do
    from [s, _gs, g] in query,
      where: g.undescribed == true
  end

  defp attach_images(galls) do
    # Get all default images for gall species
    image_map =
      Species.get_default_gall_images()
      |> Enum.into(%{}, fn %{species_id: id, path: path} -> {id, path} end)

    base_url = Image.base_url()

    Enum.map(galls, fn gall ->
      case Map.get(image_map, gall.id) do
        nil ->
          Map.put(gall, :image_url, nil)

        path ->
          Map.put(gall, :image_url, "#{base_url}/small/#{path}")
      end
    end)
  end
end
