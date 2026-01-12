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
end
