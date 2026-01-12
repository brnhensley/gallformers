defmodule Gallformers.Taxonomy do
  @moduledoc """
  The Taxonomy context.

  Provides functions for working with taxonomic classifications.
  """

  import Ecto.Query
  alias Gallformers.Repo
  alias Gallformers.Taxonomy.Taxonomy

  @doc """
  Returns all taxonomies.
  """
  @spec list_taxonomies() :: [Taxonomy.t()]
  def list_taxonomies do
    Repo.all(Taxonomy)
  end

  @doc """
  Returns all taxonomies of a specific type.
  """
  @spec list_taxonomies_by_type(String.t()) :: [Taxonomy.t()]
  def list_taxonomies_by_type(type) do
    from(t in Taxonomy,
      where: t.type == ^type,
      order_by: t.name
    )
    |> Repo.all()
  end

  @doc """
  Returns all families.
  """
  @spec list_families() :: [Taxonomy.t()]
  def list_families do
    list_taxonomies_by_type("family")
  end

  @doc """
  Returns all genera.
  """
  @spec list_genera() :: [Taxonomy.t()]
  def list_genera do
    list_taxonomies_by_type("genus")
  end

  @doc """
  Gets a taxonomy by ID.
  """
  @spec get_taxonomy(integer()) :: Taxonomy.t() | nil
  def get_taxonomy(id) do
    Repo.get(Taxonomy, id)
  end

  @doc """
  Gets a taxonomy by ID, raising if not found.
  """
  @spec get_taxonomy!(integer()) :: Taxonomy.t()
  def get_taxonomy!(id) do
    Repo.get!(Taxonomy, id)
  end

  @doc """
  Gets a taxonomy by name and type.
  """
  @spec get_taxonomy_by_name(String.t(), String.t()) :: Taxonomy.t() | nil
  def get_taxonomy_by_name(name, type) do
    from(t in Taxonomy,
      where: t.name == ^name and t.type == ^type
    )
    |> Repo.one()
  end

  @doc """
  Gets the parent taxonomy for a given taxonomy ID.
  """
  @spec get_parent(integer()) :: Taxonomy.t() | nil
  def get_parent(taxonomy_id) do
    from(t in Taxonomy,
      join: child in Taxonomy,
      on: child.parent_id == t.id,
      where: child.id == ^taxonomy_id
    )
    |> Repo.one()
  end

  @doc """
  Gets all children of a taxonomy.
  """
  @spec get_children(integer()) :: [Taxonomy.t()]
  def get_children(taxonomy_id) do
    from(t in Taxonomy,
      where: t.parent_id == ^taxonomy_id,
      order_by: t.name
    )
    |> Repo.all()
  end

  @doc """
  Gets the genus and family for a species.

  Returns a map with :genus and :family keys (or nil if not found).
  """
  @spec get_taxonomy_for_species(integer()) :: map() | nil
  def get_taxonomy_for_species(species_id) do
    query =
      from st in "speciestaxonomy",
        join: g in Taxonomy,
        on: st.taxonomy_id == g.id and g.type == "genus",
        left_join: f in Taxonomy,
        on: g.parent_id == f.id and f.type == "family",
        where: st.species_id == ^species_id,
        limit: 1,
        select: %{
          genus: g.name,
          family: f.name
        }

    Repo.one(query)
  end

  @doc """
  Gets species IDs associated with a genus.
  """
  @spec get_species_ids_for_genus(integer()) :: [integer()]
  def get_species_ids_for_genus(genus_id) do
    from(st in "speciestaxonomy",
      where: st.taxonomy_id == ^genus_id,
      select: st.species_id
    )
    |> Repo.all()
  end

  @doc """
  Gets species IDs associated with a family (via genera).
  """
  @spec get_species_ids_for_family(integer()) :: [integer()]
  def get_species_ids_for_family(family_id) do
    from(st in "speciestaxonomy",
      join: g in Taxonomy,
      on: st.taxonomy_id == g.id,
      where: g.parent_id == ^family_id,
      select: st.species_id
    )
    |> Repo.all()
  end

  @doc """
  Gets the full taxonomic path from a taxonomy up to root.

  Returns a list of taxonomies from the given taxonomy up to the root.
  """
  @spec get_taxonomy_path(integer()) :: [Taxonomy.t()]
  def get_taxonomy_path(taxonomy_id) do
    build_path(taxonomy_id, [])
  end

  defp build_path(nil, acc), do: Enum.reverse(acc)

  defp build_path(taxonomy_id, acc) do
    taxonomy = Repo.get(Taxonomy, taxonomy_id)

    if taxonomy do
      build_path(taxonomy.parent_id, [taxonomy | acc])
    else
      Enum.reverse(acc)
    end
  end
end
