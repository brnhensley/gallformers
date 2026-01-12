defmodule Gallformers.Hosts do
  @moduledoc """
  The Hosts context.

  Provides functions for working with host plants and their relationships to galls.
  """

  import Ecto.Query

  alias Gallformers.Hosts.Host
  alias Gallformers.Repo
  alias Gallformers.Species.{Gall, GallSpecies, Species}

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
      where: s.id == ^id and s.taxoncode == "plant",
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
  Searches for host species by name prefix (case-insensitive).

  Used for typeahead/autocomplete functionality.
  Returns up to `limit` results ordered by name.
  """
  @spec search_hosts(String.t(), integer()) :: [map()]
  def search_hosts(query, limit \\ 20) when is_binary(query) do
    search_pattern = "#{query}%"

    from(s in Species,
      left_join: a in "alias",
      on: a.species_id == s.id,
      where: s.taxoncode == "plant",
      where: ilike(s.name, ^search_pattern) or ilike(a.name, ^search_pattern),
      order_by: s.name,
      limit: ^limit,
      distinct: s.id,
      select: %{
        id: s.id,
        name: s.name,
        datacomplete: s.datacomplete
      }
    )
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
      where: a.species_id == ^host_id,
      select: a.name
    )
    |> Repo.all()
  end
end
