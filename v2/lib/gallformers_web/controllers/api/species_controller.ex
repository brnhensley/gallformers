defmodule GallformersWeb.API.SpeciesController do
  @moduledoc """
  API controller for species endpoints.
  """

  use GallformersWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Gallformers.Species
  alias GallformersWeb.Schemas

  tags ["Species"]

  operation :index,
    summary: "List species",
    description: "Lists all species with optional search and pagination",
    parameters: [
      q: [in: :query, type: :string, description: "Search query"],
      limit: [in: :query, type: :integer, description: "Maximum number of results"],
      offset: [in: :query, type: :integer, description: "Number of results to skip"]
    ],
    responses: [
      ok: {"List of species", "application/json", %OpenApiSpex.Schema{
        type: :object,
        properties: %{
          data: %OpenApiSpex.Schema{type: :array, items: %OpenApiSpex.Schema{type: :object}},
          total: %OpenApiSpex.Schema{type: :integer},
          limit: %OpenApiSpex.Schema{type: :integer, nullable: true},
          offset: %OpenApiSpex.Schema{type: :integer}
        }
      }}
    ]

  @doc """
  GET /api/v2/species
  Lists all species with optional search and pagination.
  """
  def index(conn, params) do
    limit = parse_int(params["limit"])
    offset = parse_int(params["offset"]) || 0
    query = params["q"]

    {species, total} =
      case {query, limit} do
        {nil, nil} ->
          all = Species.list_species()
          {Enum.map(all, &species_to_map/1), length(all)}

        {nil, limit} ->
          all = Species.list_species()
          paginated = all |> Enum.drop(offset) |> Enum.take(limit)
          {Enum.map(paginated, &species_to_map/1), length(all)}

        {query, nil} ->
          results = search_species(query)
          {results, length(results)}

        {query, limit} ->
          all = search_species(query)
          paginated = all |> Enum.drop(offset) |> Enum.take(limit)
          {paginated, length(all)}
      end

    json(conn, %{
      data: species,
      total: total,
      limit: limit,
      offset: offset
    })
  end

  operation :show,
    summary: "Get a species",
    description: "Gets a single species by ID",
    parameters: [
      id: [in: :path, type: :integer, description: "Species ID", required: true]
    ],
    responses: [
      ok: {"Species details", "application/json", %OpenApiSpex.Schema{type: :object}},
      not_found: {"Species not found", "application/json", Schemas.Error}
    ]

  @doc """
  GET /api/v2/species/:id
  Gets a single species by ID.
  """
  def show(conn, %{"id" => id}) do
    case parse_int(id) do
      nil ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid species ID"})

      id ->
        case Species.get_species(id) do
          nil ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "Species not found"})

          species ->
            json(conn, species_to_map(species))
        end
    end
  end

  defp species_to_map(species) do
    %{
      id: species.id,
      name: species.name,
      taxoncode: species.taxoncode,
      datacomplete: species.datacomplete,
      abundance_id: species.abundance_id
    }
  end

  defp search_species(query) do
    search_term = "%#{String.downcase(query)}%"

    import Ecto.Query
    alias Gallformers.Repo
    alias Gallformers.Species.Species

    from(s in Species,
      where: fragment("lower(?) LIKE ?", s.name, ^search_term),
      order_by: s.name,
      select: %{
        id: s.id,
        name: s.name,
        taxoncode: s.taxoncode,
        datacomplete: s.datacomplete,
        abundance_id: s.abundance_id
      }
    )
    |> Repo.all()
  end

  defp parse_int(nil), do: nil

  defp parse_int(str) when is_binary(str) do
    case Integer.parse(str) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp parse_int(int) when is_integer(int), do: int
end
