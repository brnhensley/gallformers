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
  Gets the genus, section, and family for a species.

  Returns a map with taxonomy names and IDs (or nil if not found).
  Section is optional and will only be present for plant hosts in genera
  that have sections (primarily Quercus).
  """
  @spec get_taxonomy_for_species(integer()) :: map() | nil
  def get_taxonomy_for_species(species_id) do
    # First get the genus, which may have a section parent before family
    base_query =
      from st in "speciestaxonomy",
        join: g in Taxonomy,
        on: st.taxonomy_id == g.id and g.type == "genus",
        left_join: parent in Taxonomy,
        on: g.parent_id == parent.id,
        where: st.species_id == ^species_id,
        limit: 1,
        select: %{
          genus: g.name,
          genus_id: g.id,
          parent_id: parent.id,
          parent_name: parent.name,
          parent_type: parent.type,
          parent_description: parent.description
        }

    case Repo.one(base_query) do
      nil ->
        nil

      result ->
        # If parent is a section, we need to get the family from section's parent
        if result.parent_type == "section" do
          family_query =
            from t in Taxonomy,
              join: parent in Taxonomy,
              on: t.parent_id == parent.id,
              where: t.id == ^result.parent_id,
              select: %{family: parent.name, family_id: parent.id}

          family_result = Repo.one(family_query) || %{family: nil, family_id: nil}

          %{
            genus: result.genus,
            genus_id: result.genus_id,
            section: result.parent_name,
            section_id: result.parent_id,
            section_description: result.parent_description,
            family: family_result.family,
            family_id: family_result.family_id
          }
        else
          # Parent is the family directly
          %{
            genus: result.genus,
            genus_id: result.genus_id,
            section: nil,
            section_id: nil,
            family: result.parent_name,
            family_id: result.parent_id
          }
        end
    end
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

  @doc """
  Searches for genera and sections by name prefix (case-insensitive).

  Used for typeahead/autocomplete functionality in the ID tool.
  Returns up to `limit` results ordered by name.
  """
  @spec search_genera_and_sections(String.t(), integer()) :: [map()]
  def search_genera_and_sections(query, limit \\ 20) when is_binary(query) do
    search_pattern = "#{String.downcase(query)}%"

    from(t in Taxonomy,
      where: t.type in ["genus", "section"],
      where: fragment("lower(?) LIKE ?", t.name, ^search_pattern),
      order_by: [t.type, t.name],
      limit: ^limit,
      select: %{
        id: t.id,
        name: t.name,
        type: t.type,
        description: t.description
      }
    )
    |> Repo.all()
  end

  @doc """
  Gets a taxonomy by name (for URL parameter lookups).
  """
  @spec get_taxonomy_by_name(String.t()) :: Taxonomy.t() | nil
  def get_taxonomy_by_name(name) when is_binary(name) do
    from(t in Taxonomy,
      where: t.name == ^name,
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Lists families for galls that occur on a given host.
  """
  @spec list_gall_families_for_host(integer()) :: [map()]
  def list_gall_families_for_host(host_id) do
    from(f in Taxonomy,
      join: g in Taxonomy,
      on: g.parent_id == f.id,
      join: st in "speciestaxonomy",
      on: st.taxonomy_id == g.id,
      join: s in Gallformers.Species.Species,
      on: st.species_id == s.id,
      join: h in Gallformers.Hosts.Host,
      on: h.gall_species_id == s.id,
      where: s.taxoncode == "gall" and f.type == "family" and h.host_species_id == ^host_id,
      group_by: [f.id, f.name],
      order_by: f.name,
      select: %{
        id: f.id,
        name: f.name
      }
    )
    |> Repo.all()
  end

  @doc """
  Gets the family for a given genus.
  """
  @spec get_family_for_genus(integer()) :: map() | nil
  def get_family_for_genus(genus_id) do
    from(f in Taxonomy,
      join: g in Taxonomy,
      on: g.parent_id == f.id,
      where: g.id == ^genus_id and f.type == "family",
      select: %{
        id: f.id,
        name: f.name
      }
    )
    |> Repo.one()
  end

  # Admin functions

  @doc """
  Returns a changeset for tracking taxonomy changes.
  """
  def change_taxonomy(%Taxonomy{} = taxonomy, attrs \\ %{}) do
    Taxonomy.changeset(taxonomy, attrs)
  end

  @doc """
  Creates a taxonomy entry.
  """
  def create_taxonomy(attrs \\ %{}) do
    %Taxonomy{}
    |> Taxonomy.changeset(attrs)
    |> Repo.insert()
    |> broadcast(:taxonomy_created)
  end

  @doc """
  Updates a taxonomy entry.
  """
  def update_taxonomy(%Taxonomy{} = taxonomy, attrs) do
    taxonomy
    |> Taxonomy.changeset(attrs)
    |> Repo.update()
    |> broadcast(:taxonomy_updated)
  end

  @doc """
  Deletes a taxonomy entry.
  """
  def delete_taxonomy(%Taxonomy{} = taxonomy) do
    Repo.delete(taxonomy)
    |> broadcast(:taxonomy_deleted)
  end

  @doc """
  Searches taxonomies by name (case-insensitive).
  """
  def search_taxonomies(query, type \\ nil, limit \\ 50) do
    search_pattern = "%#{String.downcase(query)}%"

    base_query =
      from(t in Taxonomy,
        where: fragment("lower(?) LIKE ?", t.name, ^search_pattern),
        order_by: t.name,
        limit: ^limit
      )

    query_with_type =
      if type do
        from(t in base_query, where: t.type == ^type)
      else
        base_query
      end

    Repo.all(query_with_type)
  end

  @doc """
  Returns all taxonomies with their parent preloaded, optionally filtered by type.
  """
  def list_taxonomies_with_parent(type \\ nil) do
    base_query =
      from(t in Taxonomy,
        left_join: p in Taxonomy,
        on: t.parent_id == p.id,
        order_by: [t.type, t.name],
        select: %{
          id: t.id,
          name: t.name,
          description: t.description,
          type: t.type,
          parent_id: t.parent_id,
          parent_name: p.name,
          parent_type: p.type
        }
      )

    query_with_type =
      if type do
        from([t, p] in base_query, where: t.type == ^type)
      else
        base_query
      end

    Repo.all(query_with_type)
  end

  @doc """
  Returns families for use as parent options in forms.
  """
  def list_families_for_select do
    from(t in Taxonomy,
      where: t.type == "family",
      order_by: t.name,
      select: {t.name, t.id}
    )
    |> Repo.all()
  end

  @doc """
  Returns families and sections for use as parent options for genera.
  """
  def list_parents_for_genus do
    from(t in Taxonomy,
      where: t.type in ["family", "section"],
      order_by: [t.type, t.name],
      select: %{id: t.id, name: t.name, type: t.type}
    )
    |> Repo.all()
  end

  @doc """
  Subscribes to taxonomy changes.
  """
  def subscribe do
    Phoenix.PubSub.subscribe(Gallformers.PubSub, "taxonomy")
  end

  defp broadcast({:ok, taxonomy}, event) do
    Phoenix.PubSub.broadcast(Gallformers.PubSub, "taxonomy", {event, taxonomy})
    {:ok, taxonomy}
  end

  defp broadcast({:error, changeset}, _event) do
    {:error, changeset}
  end
end
