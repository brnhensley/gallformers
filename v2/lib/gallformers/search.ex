defmodule Gallformers.Search do
  @moduledoc """
  The Search context.

  Provides functions for searching across species, hosts, and other entities.
  """

  import Ecto.Query
  alias Gallformers.Repo
  alias Gallformers.Species.{Gall, GallSpecies, Species}

  @doc """
  Searches galls by name (partial match).
  """
  @spec search_galls(String.t()) :: [map()]
  def search_galls(query) do
    search_term = "%#{query}%"

    from(s in Species,
      join: gs in GallSpecies,
      on: gs.species_id == s.id,
      join: g in Gall,
      on: gs.gall_id == g.id,
      where: s.taxoncode == "gall" and ilike(s.name, ^search_term),
      order_by: s.name,
      select: %{
        id: s.id,
        name: s.name,
        taxoncode: s.taxoncode,
        undescribed: g.undescribed
      }
    )
    |> Repo.all()
  end

  @doc """
  Searches galls by name with pagination.
  """
  @spec search_galls_paginated(String.t(), integer(), integer()) :: [map()]
  def search_galls_paginated(query, limit, offset) do
    search_term = "%#{query}%"

    from(s in Species,
      join: gs in GallSpecies,
      on: gs.species_id == s.id,
      join: g in Gall,
      on: gs.gall_id == g.id,
      where: s.taxoncode == "gall" and ilike(s.name, ^search_term),
      order_by: s.name,
      limit: ^limit,
      offset: ^offset,
      select: %{
        id: s.id,
        name: s.name,
        taxoncode: s.taxoncode,
        undescribed: g.undescribed
      }
    )
    |> Repo.all()
  end

  @doc """
  Returns the count of galls matching a search query.
  """
  @spec count_search_galls(String.t()) :: integer()
  def count_search_galls(query) do
    search_term = "%#{query}%"

    from(s in Species,
      join: gs in GallSpecies,
      on: gs.species_id == s.id,
      where: s.taxoncode == "gall" and ilike(s.name, ^search_term),
      select: count(s.id)
    )
    |> Repo.one()
  end

  @doc """
  Searches hosts by name (partial match).
  """
  @spec search_hosts(String.t()) :: [map()]
  def search_hosts(query) do
    search_term = "%#{query}%"

    from(s in Species,
      where: s.taxoncode == "plant" and ilike(s.name, ^search_term),
      order_by: s.name,
      select: %{
        id: s.id,
        name: s.name,
        taxoncode: s.taxoncode
      }
    )
    |> Repo.all()
  end

  @doc """
  Searches hosts by name with pagination.
  """
  @spec search_hosts_paginated(String.t(), integer(), integer()) :: [map()]
  def search_hosts_paginated(query, limit, offset) do
    search_term = "%#{query}%"

    from(s in Species,
      where: s.taxoncode == "plant" and ilike(s.name, ^search_term),
      order_by: s.name,
      limit: ^limit,
      offset: ^offset,
      select: %{
        id: s.id,
        name: s.name,
        taxoncode: s.taxoncode
      }
    )
    |> Repo.all()
  end

  @doc """
  Returns the count of hosts matching a search query.
  """
  @spec count_search_hosts(String.t()) :: integer()
  def count_search_hosts(query) do
    search_term = "%#{query}%"

    from(s in Species,
      where: s.taxoncode == "plant" and ilike(s.name, ^search_term),
      select: count(s.id)
    )
    |> Repo.one()
  end

  @doc """
  Searches all species (galls and hosts) by name.
  """
  @spec search_all(String.t()) :: [map()]
  def search_all(query) do
    search_term = "%#{query}%"

    from(s in Species,
      where: ilike(s.name, ^search_term),
      order_by: s.name,
      select: %{
        id: s.id,
        name: s.name,
        taxoncode: s.taxoncode
      }
    )
    |> Repo.all()
  end

  @doc """
  Returns galls that share the same binomial name prefix.

  Related galls share the same genus + species epithet but have additional qualifiers.
  Example: "Andricus quercuscalifornicus agamic" and "Andricus quercuscalifornicus sexual"
  """
  @spec get_related_galls(integer(), String.t()) :: [map()]
  def get_related_galls(exclude_id, name_prefix) do
    from(s in Species,
      join: gs in GallSpecies,
      on: gs.species_id == s.id,
      where:
        s.taxoncode == "gall" and
          like(s.name, ^"#{name_prefix}%") and
          s.id != ^exclude_id,
      order_by: s.name,
      select: %{
        id: s.id,
        name: s.name,
        taxoncode: s.taxoncode
      }
    )
    |> Repo.all()
  end
end
