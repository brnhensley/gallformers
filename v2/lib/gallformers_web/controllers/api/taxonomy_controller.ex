defmodule GallformersWeb.API.TaxonomyController do
  @moduledoc """
  API controller for taxonomy endpoints.
  """

  use GallformersWeb, :controller

  import Ecto.Query

  alias Gallformers.Repo
  alias Gallformers.Taxonomy

  @doc """
  GET /api/v2/taxonomy/:id
  Gets a single taxonomy entry by ID.
  """
  def show(conn, %{"id" => id}) do
    with {:ok, id} <- parse_id(id),
         {:ok, taxonomy} <- fetch_taxonomy(id) do
      json(conn, taxonomy_to_map(taxonomy))
    else
      {:error, :invalid_id} -> bad_request(conn, "Invalid taxonomy ID")
      {:error, :not_found} -> not_found(conn, "Taxonomy not found")
    end
  end

  @doc """
  GET /api/v2/families
  Lists all families with their genera.
  """
  def families(conn, _params) do
    families = get_families_with_genera()
    json(conn, families)
  end

  @doc """
  GET /api/v2/families/:id
  Gets a family by ID with its genera.
  """
  def family(conn, %{"id" => id}) do
    with {:ok, id} <- parse_id(id),
         {:ok, family} <- fetch_taxonomy_by_type(id, "family") do
      genera = Taxonomy.get_children(id)

      json(conn, %{
        id: family.id,
        name: family.name,
        type: family.type,
        description: family.description,
        genera: Enum.map(genera, &taxonomy_to_map/1)
      })
    else
      {:error, :invalid_id} -> bad_request(conn, "Invalid family ID")
      {:error, :not_found} -> not_found(conn, "Family not found")
    end
  end

  @doc """
  GET /api/v2/genera/:id
  Gets a genus by ID with its parent family and species.
  """
  def genus(conn, %{"id" => id}) do
    with {:ok, id} <- parse_id(id),
         {:ok, genus} <- fetch_taxonomy_by_type(id, "genus") do
      parent = Taxonomy.get_parent(id)
      species_ids = Taxonomy.get_species_ids_for_genus(id)
      species = get_species_by_ids(species_ids)

      json(conn, %{
        id: genus.id,
        name: genus.name,
        type: genus.type,
        description: genus.description,
        family: parent_to_map(parent),
        species: species
      })
    else
      {:error, :invalid_id} -> bad_request(conn, "Invalid genus ID")
      {:error, :not_found} -> not_found(conn, "Genus not found")
    end
  end

  @doc """
  GET /api/v2/sections/:id
  Gets a section by ID with its species.
  """
  def section(conn, %{"id" => id}) do
    with {:ok, id} <- parse_id(id),
         {:ok, section} <- fetch_taxonomy_by_type(id, "section") do
      species_ids = Taxonomy.get_species_ids_for_genus(id)
      species = get_species_by_ids(species_ids)

      json(conn, %{
        id: section.id,
        name: section.name,
        type: section.type,
        description: section.description,
        species: species
      })
    else
      {:error, :invalid_id} -> bad_request(conn, "Invalid section ID")
      {:error, :not_found} -> not_found(conn, "Section not found")
    end
  end

  # Private functions

  defp parse_id(id) do
    case parse_int(id) do
      nil -> {:error, :invalid_id}
      id -> {:ok, id}
    end
  end

  defp fetch_taxonomy(id) do
    case Taxonomy.get_taxonomy(id) do
      nil -> {:error, :not_found}
      taxonomy -> {:ok, taxonomy}
    end
  end

  defp fetch_taxonomy_by_type(id, expected_type) do
    case Taxonomy.get_taxonomy(id) do
      nil -> {:error, :not_found}
      %{type: ^expected_type} = taxonomy -> {:ok, taxonomy}
      _other -> {:error, :not_found}
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

  defp taxonomy_to_map(taxonomy) do
    %{
      id: taxonomy.id,
      name: taxonomy.name,
      type: taxonomy.type,
      description: taxonomy.description,
      parent_id: taxonomy.parent_id
    }
  end

  defp parent_to_map(nil), do: nil
  defp parent_to_map(parent), do: %{id: parent.id, name: parent.name}

  defp get_families_with_genera do
    families = Taxonomy.list_families()

    Enum.map(families, fn family ->
      genera = Taxonomy.get_children(family.id)

      %{
        id: family.id,
        name: family.name,
        type: family.type,
        description: family.description,
        genera: Enum.map(genera, &taxonomy_to_map/1)
      }
    end)
  end

  defp get_species_by_ids([]), do: []

  defp get_species_by_ids(ids) do
    alias Gallformers.Species.Species

    from(s in Species,
      where: s.id in ^ids,
      order_by: s.name,
      select: %{
        id: s.id,
        name: s.name,
        taxoncode: s.taxoncode
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
