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
  Returns all sections.
  """
  @spec list_sections() :: [Taxonomy.t()]
  def list_sections do
    list_taxonomies_by_type("section")
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
  Extracts the genus name from a species name (first word before space).

  ## Examples

      iex> extract_genus_from_name("Andricus quercuslanigera")
      "Andricus"

      iex> extract_genus_from_name("Test")
      "Test"
  """
  @spec extract_genus_from_name(String.t()) :: String.t() | nil
  def extract_genus_from_name(name) when is_binary(name) do
    case String.split(name, " ", parts: 2) do
      [genus_name | _] when byte_size(genus_name) > 0 -> genus_name
      _ -> nil
    end
  end

  def extract_genus_from_name(_), do: nil

  @doc """
  Looks up or prepares taxonomy info for a species name.

  Unlike `get_taxonomy_from_species_name/1`, this function always returns
  a result (never nil) to support species creation workflows:

  - If genus exists: returns full taxonomy with `genus_is_new: false`
  - If genus is NEW: returns extracted genus name with `genus_is_new: true`
    and empty family fields (user must select a family)

  ## Examples

      iex> lookup_taxonomy_for_new_species("Andricus quercuslanigera")
      %{genus: "Andricus", genus_id: 123, genus_is_new: false,
        section: nil, section_id: nil, family: "Cynipidae", family_id: 456}

      iex> lookup_taxonomy_for_new_species("Newgenus species")
      %{genus: "Newgenus", genus_id: nil, genus_is_new: true,
        section: nil, section_id: nil, family: nil, family_id: nil}
  """
  @spec lookup_taxonomy_for_new_species(String.t()) :: map() | nil
  def lookup_taxonomy_for_new_species(name) when is_binary(name) do
    case extract_genus_from_name(name) do
      nil ->
        nil

      genus_name ->
        case get_taxonomy_by_name(genus_name, "genus") do
          nil ->
            # Genus doesn't exist - this is a new genus
            %{
              genus: genus_name,
              genus_id: nil,
              genus_is_new: true,
              section: nil,
              section_id: nil,
              family: nil,
              family_id: nil
            }

          genus ->
            # Genus exists - get its family
            result = build_taxonomy_from_genus(genus)
            Map.put(result, :genus_is_new, false)
        end
    end
  end

  def lookup_taxonomy_for_new_species(_), do: nil

  # Helper to build taxonomy map from an existing genus
  defp build_taxonomy_from_genus(genus) do
    case get_parent(genus.id) do
      nil ->
        %{
          genus: genus.name,
          genus_id: genus.id,
          section: nil,
          section_id: nil,
          family: nil,
          family_id: nil
        }

      parent when parent.type == "section" ->
        family = get_parent(parent.id)

        %{
          genus: genus.name,
          genus_id: genus.id,
          section: parent.name,
          section_id: parent.id,
          family: family && family.name,
          family_id: family && family.id
        }

      parent ->
        %{
          genus: genus.name,
          genus_id: genus.id,
          section: nil,
          section_id: nil,
          family: parent.name,
          family_id: parent.id
        }
    end
  end

  @doc """
  Creates a new genus under a family and links a species to it.

  Used when creating a new species with a genus that doesn't exist yet.
  Creates the genus taxonomy entry and the species-taxonomy relationship.

  Returns `{:ok, genus}` on success or `{:error, reason}` on failure.
  """
  @spec create_genus_for_species(String.t(), integer(), integer()) ::
          {:ok, Taxonomy.t()} | {:error, term()}
  def create_genus_for_species(genus_name, family_id, species_id) do
    # Create the genus under the family
    case create_taxonomy(%{name: genus_name, type: "genus", parent_id: family_id}) do
      {:ok, genus} ->
        # Link the species to the genus
        link_species_to_taxonomy(species_id, genus.id)
        {:ok, genus}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Links a species to a taxonomy entry (genus).
  """
  @spec link_species_to_taxonomy(integer(), integer()) :: {:ok, any()} | {:error, term()}
  def link_species_to_taxonomy(species_id, taxonomy_id) do
    Repo.insert_all(
      "speciestaxonomy",
      [%{species_id: species_id, taxonomy_id: taxonomy_id}],
      on_conflict: :nothing
    )
    |> case do
      {1, _} -> {:ok, nil}
      {0, _} -> {:ok, nil}
      error -> {:error, error}
    end
  end

  @doc """
  Looks up taxonomy info (genus, section, family) from a species name.

  Extracts the genus from the first word of the species name,
  looks it up in the taxonomy table, and returns the full taxonomy path.

  Returns a map with the same structure as `get_taxonomy_for_species/1`,
  or nil if the genus is not found.

  ## Examples

      iex> get_taxonomy_from_species_name("Andricus quercuslanigera")
      %{genus: "Andricus", genus_id: 123, section: nil, section_id: nil, family: "Cynipidae", family_id: 456}

      iex> get_taxonomy_from_species_name("Unknown species")
      nil
  """
  @spec get_taxonomy_from_species_name(String.t()) :: map() | nil
  def get_taxonomy_from_species_name(name) when is_binary(name) do
    case String.split(name, " ", parts: 2) do
      [genus_name | _] when byte_size(genus_name) > 0 ->
        case get_taxonomy_by_name(genus_name, "genus") do
          nil ->
            nil

          genus ->
            # Get the parent (could be a section or family)
            case get_parent(genus.id) do
              nil ->
                %{
                  genus: genus.name,
                  genus_id: genus.id,
                  section: nil,
                  section_id: nil,
                  family: nil,
                  family_id: nil
                }

              parent when parent.type == "section" ->
                # Section's parent is the family
                family = get_parent(parent.id)

                %{
                  genus: genus.name,
                  genus_id: genus.id,
                  section: parent.name,
                  section_id: parent.id,
                  family: family && family.name,
                  family_id: family && family.id
                }

              parent ->
                # Parent is the family directly
                %{
                  genus: genus.name,
                  genus_id: genus.id,
                  section: nil,
                  section_id: nil,
                  family: parent.name,
                  family_id: parent.id
                }
            end
        end

      _ ->
        nil
    end
  end

  def get_taxonomy_from_species_name(_), do: nil

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
  @spec change_taxonomy(Taxonomy.t(), map()) :: Ecto.Changeset.t()
  def change_taxonomy(%Taxonomy{} = taxonomy, attrs \\ %{}) do
    Taxonomy.changeset(taxonomy, attrs)
  end

  @doc """
  Creates a taxonomy entry.
  """
  @spec create_taxonomy(map()) :: {:ok, Taxonomy.t()} | {:error, Ecto.Changeset.t()}
  def create_taxonomy(attrs \\ %{}) do
    %Taxonomy{}
    |> Taxonomy.changeset(attrs)
    |> Repo.insert()
    |> broadcast(:taxonomy_created)
  end

  @doc """
  Updates a taxonomy entry.
  """
  @spec update_taxonomy(Taxonomy.t(), map()) :: {:ok, Taxonomy.t()} | {:error, Ecto.Changeset.t()}
  def update_taxonomy(%Taxonomy{} = taxonomy, attrs) do
    taxonomy
    |> Taxonomy.changeset(attrs)
    |> Repo.update()
    |> broadcast(:taxonomy_updated)
  end

  @doc """
  Deletes a taxonomy entry.
  """
  @spec delete_taxonomy(Taxonomy.t()) :: {:ok, Taxonomy.t()} | {:error, Ecto.Changeset.t()}
  def delete_taxonomy(%Taxonomy{} = taxonomy) do
    Repo.delete(taxonomy)
    |> broadcast(:taxonomy_deleted)
  end

  @doc """
  Finds or creates an "Unknown" genus under the given family.

  Used for undescribed galls where the genus is not known.
  Returns {:ok, genus} or {:error, changeset}.
  """
  @spec find_or_create_unknown_genus(integer()) ::
          {:ok, Taxonomy.t()} | {:error, Ecto.Changeset.t()}
  def find_or_create_unknown_genus(family_id) do
    # Check if an Unknown genus already exists under this family
    case Repo.one(
           from(t in Taxonomy,
             where: t.name == "Unknown" and t.type == "genus" and t.parent_id == ^family_id
           )
         ) do
      nil ->
        # Create a new Unknown genus under the family
        create_taxonomy(%{
          name: "Unknown",
          type: "genus",
          parent_id: family_id,
          description: "Placeholder genus for undescribed species"
        })

      existing ->
        {:ok, existing}
    end
  end

  @doc """
  Searches taxonomies by name (case-insensitive).
  """
  @spec search_taxonomies(String.t(), String.t() | nil, integer()) :: [Taxonomy.t()]
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
  @spec list_taxonomies_with_parent(String.t() | nil) :: [map()]
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
  @spec list_families_for_select() :: [{String.t(), integer()}]
  def list_families_for_select do
    from(t in Taxonomy,
      where: t.type == "family",
      order_by: t.name,
      select: {t.name, t.id}
    )
    |> Repo.all()
  end

  @doc """
  Returns genera for use in typeahead/select components.
  Each result includes the parent family ID for auto-population.
  Excludes genera named "Unknown" as those are created automatically.
  """
  @spec list_genera_for_select() :: [map()]
  def list_genera_for_select do
    from(g in Taxonomy,
      left_join: p in Taxonomy,
      on: g.parent_id == p.id,
      left_join: gp in Taxonomy,
      on: p.parent_id == gp.id,
      where: g.type == "genus" and g.name != "Unknown",
      order_by: g.name,
      select: %{
        id: g.id,
        name: g.name,
        # If parent is a section, grandparent is the family
        # If parent is a family, that's the family
        family_id:
          fragment(
            "CASE WHEN ? = 'section' THEN ? ELSE ? END",
            p.type,
            gp.id,
            p.id
          )
      }
    )
    |> Repo.all()
  end

  @doc """
  Returns families and sections for use as parent options for genera.
  """
  @spec list_parents_for_genus() :: [map()]
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
  @spec subscribe() :: :ok | {:error, term()}
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
