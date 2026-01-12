defmodule GallformersWeb.API.GallController do
  @moduledoc """
  API controller for gall endpoints.
  """

  use GallformersWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import Ecto.Query

  alias Gallformers.{Hosts, Repo, Search, Species, Taxonomy}
  alias Gallformers.Species.{Gall, GallSpecies, Image}
  alias Gallformers.Species.Species, as: SpeciesSchema
  alias GallformersWeb.Schemas

  tags ["Galls"]

  operation :index,
    summary: "List galls",
    description: "Lists all galls with optional search and pagination",
    parameters: [
      q: [in: :query, type: :string, description: "Search query"],
      limit: [in: :query, type: :integer, description: "Maximum number of results"],
      offset: [in: :query, type: :integer, description: "Number of results to skip"]
    ],
    responses: [
      ok: {"List of galls", "application/json", Schemas.GallListResponse}
    ]

  @doc """
  GET /api/v2/galls
  Lists all galls with optional search and pagination.
  """
  def index(conn, params) do
    limit = parse_int(params["limit"])
    offset = parse_int(params["offset"]) || 0
    query = params["q"]

    {galls, total} =
      case {query, limit} do
        {nil, nil} ->
          all = Species.list_galls()
          {Enum.map(all, &gall_to_response/1), length(all)}

        {nil, limit} ->
          total = Species.count_galls()
          paginated = Species.list_galls_paginated(limit, offset)
          {Enum.map(paginated, &gall_to_response/1), total}

        {query, nil} ->
          results = Search.search_galls(query)
          {Enum.map(results, &gall_to_response/1), length(results)}

        {query, limit} ->
          total = Search.count_search_galls(query)
          results = Search.search_galls_paginated(query, limit, offset)
          {Enum.map(results, &gall_to_response/1), total}
      end

    json(conn, %{
      data: galls,
      total: total,
      limit: limit,
      offset: offset
    })
  end

  operation :show,
    summary: "Get a gall",
    description: "Gets a single gall by ID with full details",
    parameters: [
      id: [in: :path, type: :integer, description: "Gall ID", required: true]
    ],
    responses: [
      ok: {"Gall details", "application/json", Schemas.Gall},
      not_found: {"Gall not found", "application/json", Schemas.Error}
    ]

  @doc """
  GET /api/v2/galls/:id
  Gets a single gall by ID with full details.
  """
  def show(conn, %{"id" => id}) do
    case parse_int(id) do
      nil ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid gall ID"})

      id ->
        case Species.get_gall_by_id(id) do
          nil ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "Gall not found"})

          gall ->
            json(conn, gall_to_full_response(gall))
        end
    end
  end

  operation :random,
    summary: "Get a random gall",
    description: "Returns a random gall with its image for the home page",
    responses: [
      ok: {"Random gall", "application/json", Schemas.RandomGall},
      not_found: {"No galls with images found", "application/json", Schemas.Error}
    ]

  @doc """
  GET /api/v2/galls/random
  Returns a random gall with its image for the home page.
  """
  def random(conn, _params) do
    case Species.random_gall() do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "No galls with images found"})

      gall ->
        json(conn, %{
          id: gall.id,
          name: gall.name,
          undescribed: gall.undescribed,
          image_path: gall.image_path,
          image_url: gall.image_url,
          image_creator: gall.image_creator,
          image_license: gall.image_license
        })
    end
  end

  operation :id_tool,
    summary: "Get galls for ID tool",
    description: "Returns all galls with filter fields for the ID tool",
    responses: [
      ok: {"List of galls for ID tool", "application/json", %OpenApiSpex.Schema{type: :array, items: Schemas.IDGall}}
    ]

  @doc """
  GET /api/v2/galls/id
  Returns all galls with filter fields for the ID tool.
  """
  def id_tool(conn, _params) do
    galls = get_galls_for_id_tool()
    json(conn, galls)
  end

  operation :images,
    summary: "Get gall images",
    description: "Returns all images for a gall species",
    parameters: [
      id: [in: :path, type: :integer, description: "Gall species ID", required: true]
    ],
    responses: [
      ok: {"List of images", "application/json", %OpenApiSpex.Schema{type: :array, items: Schemas.Image}}
    ]

  @doc """
  GET /api/v2/galls/:id/images
  Returns all images for a gall species.
  """
  def images(conn, %{"id" => id}) do
    case parse_int(id) do
      nil ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid species ID"})

      id ->
        images = Species.get_images_for_species(id)
        base_url = Image.base_url()

        response =
          Enum.map(images, fn img ->
            %{
              id: img.id,
              path: img.path,
              url: "#{base_url}/#{img.path}",
              default: img.default,
              creator: img.creator,
              attribution: img.attribution,
              sourcelink: img.sourcelink,
              license: img.license,
              licenselink: img.licenselink,
              caption: img.caption
            }
          end)

        json(conn, response)
    end
  end

  operation :related,
    summary: "Get related galls",
    description: "Returns galls with the same binomial name",
    parameters: [
      id: [in: :path, type: :integer, description: "Gall ID", required: true]
    ],
    responses: [
      ok: {"List of related galls", "application/json", %OpenApiSpex.Schema{type: :array, items: Schemas.RelatedGall}},
      not_found: {"Gall not found", "application/json", Schemas.Error}
    ]

  @doc """
  GET /api/v2/galls/:id/related
  Returns galls with the same binomial name.
  """
  def related(conn, %{"id" => id}) do
    with {:ok, id} <- parse_id(id),
         {:ok, gall} <- fetch_gall(id) do
      related = find_related_galls(gall, id)
      response = Enum.map(related, fn r -> %{id: r.id, name: r.name} end)
      json(conn, response)
    else
      {:error, :invalid_id} -> bad_request(conn, "Invalid gall ID")
      {:error, :not_found} -> not_found(conn, "Gall not found")
    end
  end

  defp parse_id(id) do
    case parse_int(id) do
      nil -> {:error, :invalid_id}
      id -> {:ok, id}
    end
  end

  defp fetch_gall(id) do
    case Species.get_gall_by_id(id) do
      nil -> {:error, :not_found}
      gall -> {:ok, gall}
    end
  end

  defp find_related_galls(gall, id) do
    name_parts = String.split(gall.name)

    if length(name_parts) >= 2 do
      prefix = "#{Enum.at(name_parts, 0)} #{Enum.at(name_parts, 1)}"
      Search.get_related_galls(id, prefix)
    else
      []
    end
  end

  defp bad_request(conn, message) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: message})
  end

  defp not_found(conn, message) do
    conn
    |> put_status(:not_found)
    |> json(%{error: message})
  end

  # Private functions

  defp gall_to_response(gall) do
    aliases = Species.get_aliases_for_species(gall.id)

    %{
      id: gall.id,
      name: gall.name,
      gall_id: gall.gall_id,
      datacomplete: gall.datacomplete,
      abundance_id: gall.abundance_id,
      abundance: gall.abundance_name,
      detachable: gall.detachable,
      undescribed: gall.undescribed,
      aliases: Enum.map(aliases, &alias_to_map/1)
    }
  end

  defp gall_to_full_response(gall) do
    aliases = Species.get_aliases_for_species(gall.id)
    hosts = Hosts.get_hosts_for_gall(gall.id)
    filter_fields = get_filter_fields_for_gall(gall.gall_id)
    places = Hosts.get_places_for_gall(gall.id)
    excluded_places = Hosts.get_excluded_places_for_gall(gall.id)

    %{
      id: gall.id,
      name: gall.name,
      gall_id: gall.gall_id,
      datacomplete: gall.datacomplete,
      abundance_id: gall.abundance_id,
      abundance: gall.abundance_name,
      detachable: gall.detachable,
      undescribed: gall.undescribed,
      aliases: Enum.map(aliases, &alias_to_map/1),
      hosts: Enum.map(hosts, fn h -> %{id: h.host_species_id, name: h.host_name} end),
      colors: filter_fields.colors,
      shapes: filter_fields.shapes,
      textures: filter_fields.textures,
      locations: filter_fields.locations,
      alignments: filter_fields.alignments,
      walls: filter_fields.walls,
      cells: filter_fields.cells,
      seasons: filter_fields.seasons,
      forms: filter_fields.forms,
      places: places,
      excludedPlaces: excluded_places
    }
  end

  defp alias_to_map(a) do
    %{
      id: a.id,
      name: a.name,
      type: a.type,
      description: a.description
    }
  end

  defp get_filter_fields_for_gall(gall_id) do
    %{
      colors: get_gall_colors(gall_id),
      shapes: get_gall_shapes(gall_id),
      textures: get_gall_textures(gall_id),
      locations: get_gall_locations(gall_id),
      alignments: get_gall_alignments(gall_id),
      walls: get_gall_walls(gall_id),
      cells: get_gall_cells(gall_id),
      seasons: get_gall_seasons(gall_id),
      forms: get_gall_forms(gall_id)
    }
  end

  defp get_gall_colors(gall_id) do
    from(gc in "gallcolor",
      join: c in "color",
      on: gc.color_id == c.id,
      where: gc.gall_id == ^gall_id,
      select: %{id: c.id, field: c.color}
    )
    |> Repo.all()
  end

  defp get_gall_shapes(gall_id) do
    from(gs in "gallshape",
      join: s in "shape",
      on: gs.shape_id == s.id,
      where: gs.gall_id == ^gall_id,
      select: %{id: s.id, field: s.shape}
    )
    |> Repo.all()
  end

  defp get_gall_textures(gall_id) do
    from(gt in "galltexture",
      join: t in "texture",
      on: gt.texture_id == t.id,
      where: gt.gall_id == ^gall_id,
      select: %{id: t.id, field: t.texture}
    )
    |> Repo.all()
  end

  defp get_gall_locations(gall_id) do
    from(gl in "galllocation",
      join: l in "location",
      on: gl.location_id == l.id,
      where: gl.gall_id == ^gall_id,
      select: %{id: l.id, field: l.location}
    )
    |> Repo.all()
  end

  defp get_gall_alignments(gall_id) do
    from(ga in "gallalignment",
      join: a in "alignment",
      on: ga.alignment_id == a.id,
      where: ga.gall_id == ^gall_id,
      select: %{id: a.id, field: a.alignment}
    )
    |> Repo.all()
  end

  defp get_gall_walls(gall_id) do
    from(gw in "gallwalls",
      join: w in "walls",
      on: gw.walls_id == w.id,
      where: gw.gall_id == ^gall_id,
      select: %{id: w.id, field: w.walls}
    )
    |> Repo.all()
  end

  defp get_gall_cells(gall_id) do
    from(gc in "gallcells",
      join: c in "cells",
      on: gc.cells_id == c.id,
      where: gc.gall_id == ^gall_id,
      select: %{id: c.id, field: c.cells}
    )
    |> Repo.all()
  end

  defp get_gall_seasons(gall_id) do
    from(gs in "gallseason",
      join: s in "season",
      on: gs.season_id == s.id,
      where: gs.gall_id == ^gall_id,
      select: %{id: s.id, field: s.season}
    )
    |> Repo.all()
  end

  defp get_gall_forms(gall_id) do
    from(gf in "gallform",
      join: f in "form",
      on: gf.form_id == f.id,
      where: gf.gall_id == ^gall_id,
      select: %{id: f.id, field: f.form}
    )
    |> Repo.all()
  end

  defp get_galls_for_id_tool do
    # Get all galls with basic info
    galls =
      from(s in SpeciesSchema,
        join: gs in GallSpecies,
        on: gs.species_id == s.id,
        join: g in Gall,
        on: gs.gall_id == g.id,
        where: s.taxoncode == "gall",
        order_by: s.name,
        select: %{
          id: s.id,
          name: s.name,
          gall_id: g.id,
          detachable: g.detachable,
          undescribed: g.undescribed
        }
      )
      |> Repo.all()

    # Get default images for all gall species
    image_map =
      Species.get_default_gall_images()
      |> Enum.into(%{}, fn %{species_id: id, path: path} -> {id, path} end)

    base_url = Image.base_url()

    # Build the full response for each gall
    Enum.map(galls, fn gall ->
      filter_fields = get_filter_fields_strings_for_gall(gall.gall_id)
      hosts = Hosts.get_hosts_for_gall(gall.id)
      places = Hosts.get_places_for_gall(gall.id)
      taxonomy = Taxonomy.get_taxonomy_for_species(gall.id)

      image_url =
        case Map.get(image_map, gall.id) do
          nil -> nil
          path -> "#{base_url}/#{path}"
        end

      %{
        id: gall.id,
        name: gall.name,
        undescribed: gall.undescribed,
        detachable: detachable_to_string(gall.detachable),
        alignments: filter_fields.alignments,
        cells: filter_fields.cells,
        colors: filter_fields.colors,
        forms: filter_fields.forms,
        locations: filter_fields.locations,
        seasons: filter_fields.seasons,
        shapes: filter_fields.shapes,
        textures: filter_fields.textures,
        walls: filter_fields.walls,
        places: places,
        family: (taxonomy && taxonomy.family) || "",
        genus: (taxonomy && taxonomy.genus) || "",
        hosts: Enum.map(hosts, fn h -> %{id: h.host_species_id, name: h.host_name} end),
        imageUrl: image_url
      }
    end)
  end

  defp get_filter_fields_strings_for_gall(gall_id) do
    %{
      colors: get_color_strings(gall_id),
      shapes: get_shape_strings(gall_id),
      textures: get_texture_strings(gall_id),
      locations: get_location_strings(gall_id),
      alignments: get_alignment_strings(gall_id),
      walls: get_walls_strings(gall_id),
      cells: get_cells_strings(gall_id),
      seasons: get_season_strings(gall_id),
      forms: get_form_strings(gall_id)
    }
  end

  defp get_color_strings(gall_id) do
    from(gc in "gallcolor",
      join: c in "color",
      on: gc.color_id == c.id,
      where: gc.gall_id == ^gall_id,
      select: c.color
    )
    |> Repo.all()
  end

  defp get_shape_strings(gall_id) do
    from(gs in "gallshape",
      join: s in "shape",
      on: gs.shape_id == s.id,
      where: gs.gall_id == ^gall_id,
      select: s.shape
    )
    |> Repo.all()
  end

  defp get_texture_strings(gall_id) do
    from(gt in "galltexture",
      join: t in "texture",
      on: gt.texture_id == t.id,
      where: gt.gall_id == ^gall_id,
      select: t.texture
    )
    |> Repo.all()
  end

  defp get_location_strings(gall_id) do
    from(gl in "galllocation",
      join: l in "location",
      on: gl.location_id == l.id,
      where: gl.gall_id == ^gall_id,
      select: l.location
    )
    |> Repo.all()
  end

  defp get_alignment_strings(gall_id) do
    from(ga in "gallalignment",
      join: a in "alignment",
      on: ga.alignment_id == a.id,
      where: ga.gall_id == ^gall_id,
      select: a.alignment
    )
    |> Repo.all()
  end

  defp get_walls_strings(gall_id) do
    from(gw in "gallwalls",
      join: w in "walls",
      on: gw.walls_id == w.id,
      where: gw.gall_id == ^gall_id,
      select: w.walls
    )
    |> Repo.all()
  end

  defp get_cells_strings(gall_id) do
    from(gc in "gallcells",
      join: c in "cells",
      on: gc.cells_id == c.id,
      where: gc.gall_id == ^gall_id,
      select: c.cells
    )
    |> Repo.all()
  end

  defp get_season_strings(gall_id) do
    from(gs in "gallseason",
      join: s in "season",
      on: gs.season_id == s.id,
      where: gs.gall_id == ^gall_id,
      select: s.season
    )
    |> Repo.all()
  end

  defp get_form_strings(gall_id) do
    from(gf in "gallform",
      join: f in "form",
      on: gf.form_id == f.id,
      where: gf.gall_id == ^gall_id,
      select: f.form
    )
    |> Repo.all()
  end

  defp detachable_to_string(nil), do: ""
  defp detachable_to_string(0), do: ""
  defp detachable_to_string(1), do: "integral"
  defp detachable_to_string(2), do: "detachable"
  defp detachable_to_string(3), do: "both"
  defp detachable_to_string(_), do: ""

  defp parse_int(nil), do: nil

  defp parse_int(str) when is_binary(str) do
    case Integer.parse(str) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp parse_int(int) when is_integer(int), do: int
end
