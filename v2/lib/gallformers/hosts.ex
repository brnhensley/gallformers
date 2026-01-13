defmodule Gallformers.Hosts do
  @moduledoc """
  The Hosts context.

  Provides functions for working with host plants and their relationships to galls.
  """

  import Ecto.Query

  alias Gallformers.Hosts.Host
  alias Gallformers.Repo
  alias Gallformers.Species.{Abundance, Gall, GallSpecies, Species}

  @doc """
  Returns all host species ordered by name.
  """
  @spec list_hosts() :: [map()]
  def list_hosts do
    from(s in Species,
      where: s.taxoncode == "plant",
      order_by: s.name,
      select: %{
        id: s.id,
        name: s.name,
        taxoncode: s.taxoncode,
        datacomplete: s.datacomplete
      }
    )
    |> Repo.all()
  end

  @doc """
  Returns paginated host species.
  """
  @spec list_hosts_paginated(integer(), integer()) :: [map()]
  def list_hosts_paginated(limit, offset) do
    from(s in Species,
      where: s.taxoncode == "plant",
      order_by: s.name,
      limit: ^limit,
      offset: ^offset,
      select: %{
        id: s.id,
        name: s.name,
        taxoncode: s.taxoncode,
        datacomplete: s.datacomplete
      }
    )
    |> Repo.all()
  end

  @doc """
  Returns the count of all host species.
  """
  @spec count_hosts() :: integer()
  def count_hosts do
    from(s in Species,
      where: s.taxoncode == "plant",
      select: count(s.id)
    )
    |> Repo.one()
  end

  @doc """
  Gets a host species by ID.
  """
  @spec get_host(integer()) :: map() | nil
  def get_host(id) do
    from(s in Species,
      left_join: a in Abundance,
      on: s.abundance_id == a.id,
      where: s.id == ^id and s.taxoncode == "plant",
      select: %{
        id: s.id,
        name: s.name,
        taxoncode: s.taxoncode,
        datacomplete: s.datacomplete,
        abundance_id: s.abundance_id,
        abundance_name: a.abundance
      }
    )
    |> Repo.one()
  end

  @doc """
  Gets a host species by name.
  """
  @spec get_host_by_name(String.t()) :: map() | nil
  def get_host_by_name(name) do
    from(s in Species,
      where: s.name == ^name and s.taxoncode == "plant",
      select: %{
        id: s.id,
        name: s.name,
        taxoncode: s.taxoncode,
        datacomplete: s.datacomplete
      }
    )
    |> Repo.one()
  end

  @doc """
  Gets all hosts for a gall species.

  Returns a list of maps with host_relation_id, host_species_id, and host_name.
  """
  @spec get_hosts_for_gall(integer()) :: [map()]
  def get_hosts_for_gall(gall_species_id) do
    from(h in Host,
      join: s in Species,
      on: h.host_species_id == s.id,
      where: h.gall_species_id == ^gall_species_id,
      select: %{
        host_relation_id: h.id,
        host_species_id: s.id,
        host_name: s.name
      }
    )
    |> Repo.all()
  end

  @doc """
  Gets all galls for a host species.

  Returns a list of maps with gall info.
  """
  @spec get_galls_for_host(integer()) :: [map()]
  def get_galls_for_host(host_species_id) do
    from(h in Host,
      join: s in Species,
      on: h.gall_species_id == s.id,
      join: gs in GallSpecies,
      on: gs.species_id == s.id,
      join: g in Gall,
      on: gs.gall_id == g.id,
      where: h.host_species_id == ^host_species_id,
      select: %{
        id: s.id,
        name: s.name,
        undescribed: g.undescribed
      }
    )
    |> Repo.all()
  end

  @doc """
  Gets place codes for a host species (range data).
  """
  @spec get_places_for_host(integer()) :: [String.t()]
  def get_places_for_host(host_species_id) do
    from(sp in "speciesplace",
      join: p in "place",
      on: sp.place_id == p.id,
      where: sp.species_id == ^host_species_id,
      select: p.code
    )
    |> Repo.all()
  end

  @doc """
  Gets place codes for a gall species via its hosts.
  """
  @spec get_places_for_gall(integer()) :: [String.t()]
  def get_places_for_gall(gall_species_id) do
    from(p in "place",
      join: sp in "speciesplace",
      on: sp.place_id == p.id,
      join: h in Host,
      on: h.host_species_id == sp.species_id,
      where: h.gall_species_id == ^gall_species_id,
      distinct: true,
      select: p.code
    )
    |> Repo.all()
  end

  @doc """
  Gets excluded place codes for a gall species (direct range exclusions).
  """
  @spec get_excluded_places_for_gall(integer()) :: [String.t()]
  def get_excluded_places_for_gall(gall_species_id) do
    from(p in "place",
      join: sp in "speciesplace",
      on: sp.place_id == p.id,
      where: sp.species_id == ^gall_species_id,
      distinct: true,
      select: p.code
    )
    |> Repo.all()
  end

  @doc """
  Searches for host species by name (case-insensitive).

  Supports multi-word queries where each word must match somewhere in the name.
  For example, "q alba" matches "Quercus alba".

  Used for typeahead/autocomplete functionality.
  Returns up to `limit` results ordered by name.
  """
  @spec search_hosts(String.t(), integer()) :: [map()]
  def search_hosts(query, limit \\ 20) when is_binary(query) do
    terms =
      query
      |> String.downcase()
      |> String.split(~r/\s+/, trim: true)
      |> Enum.map(&"%#{&1}%")

    if terms == [] do
      []
    else
      search_hosts_with_terms(terms, limit)
    end
  end

  defp search_hosts_with_terms(terms, limit) do
    base_query =
      from(s in Species,
        left_join: als in "aliasspecies",
        on: als.species_id == s.id,
        left_join: a in "alias",
        on: a.id == als.alias_id,
        where: s.taxoncode == "plant",
        group_by: [s.id, s.name, s.datacomplete],
        order_by: s.name,
        limit: ^limit,
        select: %{
          id: s.id,
          name: s.name,
          datacomplete: s.datacomplete
        }
      )

    # Add a WHERE clause for each search term (all must match)
    query_with_terms =
      Enum.reduce(terms, base_query, fn term, q ->
        from([s, als, a] in q,
          where:
            fragment("lower(?) LIKE ?", s.name, ^term) or
              fragment("lower(?) LIKE ?", a.name, ^term)
        )
      end)

    query_with_terms
    |> Repo.all()
    |> Enum.map(fn host ->
      aliases = get_aliases_for_host(host.id)
      Map.put(host, :aliases, aliases)
    end)
  end

  @doc """
  Gets aliases for a host species.
  """
  @spec get_aliases_for_host(integer()) :: [String.t()]
  def get_aliases_for_host(host_id) do
    from(a in "alias",
      join: als in "aliasspecies",
      on: als.alias_id == a.id,
      where: als.species_id == ^host_id,
      select: a.name
    )
    |> Repo.all()
  end

  @doc """
  Returns a host with all related data for admin editing.
  """
  def get_host_for_edit(id) do
    host = get_host(id)

    if host do
      taxonomy = Gallformers.Taxonomy.get_taxonomy_for_species(id)
      places = get_places_for_host(id)
      aliases = get_aliases_for_host(id)

      host
      |> Map.put(:taxonomy, taxonomy)
      |> Map.put(:places, places)
      |> Map.put(:aliases, aliases)
    else
      nil
    end
  end

  @doc """
  Subscribes to host changes.
  """
  def subscribe do
    Phoenix.PubSub.subscribe(Gallformers.PubSub, "hosts")
  end

  @doc """
  Broadcasts a host change event.
  """
  def broadcast_change(host, event) do
    Phoenix.PubSub.broadcast(Gallformers.PubSub, "hosts", {event, host})
    {:ok, host}
  end

  # ============================================
  # CRUD Operations
  # ============================================

  @doc """
  Returns a changeset for tracking host changes.
  """
  def change_host(%Species{} = host, attrs \\ %{}) do
    Species.changeset(host, Map.put(attrs, "taxoncode", "plant"))
  end

  @doc """
  Creates a new host species.
  """
  def create_host(attrs) do
    attrs = Map.put(attrs, "taxoncode", "plant")

    %Species{}
    |> Species.changeset(attrs)
    |> Repo.insert()
    |> broadcast(:host_created)
  end

  @doc """
  Updates a host species.
  """
  def update_host(%Species{} = host, attrs) do
    host
    |> Species.changeset(attrs)
    |> Repo.update()
    |> broadcast(:host_updated)
  end

  @doc """
  Gets a host species by ID as a Species struct (for changesets).
  """
  def get_host_species(id) do
    from(s in Species,
      where: s.id == ^id and s.taxoncode == "plant"
    )
    |> Repo.one()
  end

  @doc """
  Deletes a host species and all associations.
  """
  def delete_host(host_id) do
    case get_host_species(host_id) do
      nil ->
        {:error, :not_found}

      host ->
        Repo.delete(host)
        |> broadcast(:host_deleted)
    end
  end

  # ============================================
  # Place/Range Management
  # ============================================

  @doc """
  Gets place IDs (not codes) for a host species.
  """
  @spec get_place_ids_for_host(integer()) :: [integer()]
  def get_place_ids_for_host(host_species_id) do
    from(sp in "speciesplace",
      where: sp.species_id == ^host_species_id,
      select: sp.place_id
    )
    |> Repo.all()
  end

  @doc """
  Adds a place to a host's range.
  """
  def add_place_to_host(host_species_id, place_id) do
    Repo.insert_all(
      "speciesplace",
      [%{species_id: host_species_id, place_id: place_id}],
      on_conflict: :nothing
    )

    broadcast({:ok, %{id: host_species_id}}, :host_updated)
  end

  @doc """
  Removes a place from a host's range.
  """
  def remove_place_from_host(host_species_id, place_id) do
    from(sp in "speciesplace",
      where: sp.species_id == ^host_species_id and sp.place_id == ^place_id
    )
    |> Repo.delete_all()

    broadcast({:ok, %{id: host_species_id}}, :host_updated)
  end

  @doc """
  Toggles a place in a host's range (add if not present, remove if present).
  Returns {:added, place_id} or {:removed, place_id}.
  """
  def toggle_place_for_host(host_species_id, place_id) do
    existing =
      from(sp in "speciesplace",
        where: sp.species_id == ^host_species_id and sp.place_id == ^place_id,
        select: count()
      )
      |> Repo.one()

    if existing > 0 do
      remove_place_from_host(host_species_id, place_id)
      {:removed, place_id}
    else
      add_place_to_host(host_species_id, place_id)
      {:added, place_id}
    end
  end

  @doc """
  Bulk updates all places for a host (replaces existing).
  """
  def update_host_places(host_species_id, place_ids) do
    Repo.transaction(fn ->
      # Delete existing
      from(sp in "speciesplace",
        where: sp.species_id == ^host_species_id
      )
      |> Repo.delete_all()

      # Insert new
      if place_ids != [] do
        entries = Enum.map(place_ids, &%{species_id: host_species_id, place_id: &1})
        Repo.insert_all("speciesplace", entries)
      end

      :ok
    end)

    broadcast({:ok, %{id: host_species_id}}, :host_updated)
  end

  # ============================================
  # Alias Management (wrappers for convenience)
  # ============================================

  @doc """
  Gets aliases for a host with full details (id, name, type).
  """
  @spec get_aliases_for_host_full(integer()) :: [map()]
  def get_aliases_for_host_full(host_id) do
    from(a in "alias",
      join: als in "aliasspecies",
      on: als.alias_id == a.id,
      where: als.species_id == ^host_id,
      select: %{id: a.id, name: a.name, type: a.type}
    )
    |> Repo.all()
  end

  @doc """
  Creates an alias for a host.
  Delegates to Species.create_alias_for_species/2.
  """
  def create_alias_for_host(host_id, alias_attrs) do
    Gallformers.Species.create_alias_for_species(host_id, alias_attrs)
  end

  @doc """
  Removes an alias from a host.
  Delegates to Species.remove_alias_from_species/2.
  """
  def remove_alias_from_host(host_id, alias_id) do
    Gallformers.Species.remove_alias_from_species(host_id, alias_id)
  end

  # ============================================
  # Rename Support
  # ============================================

  @doc """
  Renames a host species, optionally adding the old name as an alias.
  """
  def rename_host(host_id, new_name, add_alias? \\ false) do
    with {:ok, host} <- fetch_host_species(host_id),
         :ok <- check_name_available(new_name, host_id),
         {:ok, updated_host} <- do_rename_host(host, new_name) do
      maybe_add_alias(host_id, host.name, add_alias?)
      broadcast({:ok, updated_host}, :host_updated)
    end
  end

  defp fetch_host_species(host_id) do
    case get_host_species(host_id) do
      nil -> {:error, :not_found}
      host -> {:ok, host}
    end
  end

  defp check_name_available(new_name, host_id) do
    existing =
      from(s in Species,
        where: s.name == ^new_name and s.id != ^host_id
      )
      |> Repo.one()

    if existing, do: {:error, :name_exists}, else: :ok
  end

  defp do_rename_host(host, new_name) do
    host
    |> Species.changeset(%{name: new_name})
    |> Repo.update()
  end

  defp maybe_add_alias(host_id, old_name, true) do
    Gallformers.Species.create_alias_for_species(host_id, %{
      name: old_name,
      type: "scientific synonym"
    })
  end

  defp maybe_add_alias(_host_id, _old_name, false), do: :ok

  defp broadcast({:ok, host}, event) do
    Phoenix.PubSub.broadcast(Gallformers.PubSub, "hosts", {event, host})
    {:ok, host}
  end

  defp broadcast({:error, changeset}, _event) do
    {:error, changeset}
  end
end
