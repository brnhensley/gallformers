defmodule Gallformers.Search do
  @moduledoc """
  The Search context.

  Provides functions for searching across species, hosts, and other entities.
  """

  import Ecto.Query

  alias Gallformers.Glossary.Glossary
  alias Gallformers.Places.Place
  alias Gallformers.Repo
  alias Gallformers.Sources.Source
  alias Gallformers.Species.{Alias, Gall, GallSpecies, Species}
  alias Gallformers.Taxonomy.Taxonomy

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

  @doc """
  Performs a global search across all entity types.

  Returns a map with results grouped by type.
  """
  @spec global_search(String.t()) :: map()
  def global_search(query) when is_binary(query) do
    trimmed = String.trim(query)

    if trimmed == "" do
      empty_results()
    else
      %{
        galls: search_galls_with_aliases(trimmed),
        hosts: search_hosts_with_aliases(trimmed),
        glossary: search_glossary(trimmed),
        sources: search_sources(trimmed),
        taxonomy: search_taxonomy(trimmed),
        places: search_places(trimmed)
      }
    end
  end

  @doc """
  Returns empty search results.
  """
  @spec empty_results() :: map()
  def empty_results do
    %{
      galls: [],
      hosts: [],
      glossary: [],
      sources: [],
      taxonomy: [],
      places: []
    }
  end

  @doc """
  Searches galls by name or alias.
  """
  @spec search_galls_with_aliases(String.t()) :: [map()]
  def search_galls_with_aliases(query) do
    search_term = "%#{query}%"

    # Search by species name
    name_results =
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
          type: "gall",
          undescribed: g.undescribed,
          aliases: []
        }
      )
      |> Repo.all()

    # Search by alias name and return the parent species
    alias_results =
      from(a in Alias,
        join: s in assoc(a, :species),
        join: gs in GallSpecies,
        on: gs.species_id == s.id,
        join: g in Gall,
        on: gs.gall_id == g.id,
        where: s.taxoncode == "gall" and ilike(a.name, ^search_term),
        order_by: s.name,
        select: %{
          id: s.id,
          name: s.name,
          type: "gall",
          undescribed: g.undescribed,
          alias_match: a.name
        }
      )
      |> Repo.all()

    # Merge results, adding aliases to species that were found via alias
    merge_species_with_aliases(name_results, alias_results)
  end

  @doc """
  Searches hosts by name or alias.
  """
  @spec search_hosts_with_aliases(String.t()) :: [map()]
  def search_hosts_with_aliases(query) do
    search_term = "%#{query}%"

    # Search by species name
    name_results =
      from(s in Species,
        where: s.taxoncode == "plant" and ilike(s.name, ^search_term),
        order_by: s.name,
        select: %{
          id: s.id,
          name: s.name,
          type: "host",
          aliases: []
        }
      )
      |> Repo.all()

    # Search by alias name
    alias_results =
      from(a in Alias,
        join: s in assoc(a, :species),
        where: s.taxoncode == "plant" and ilike(a.name, ^search_term),
        order_by: s.name,
        select: %{
          id: s.id,
          name: s.name,
          type: "host",
          alias_match: a.name
        }
      )
      |> Repo.all()

    merge_species_with_aliases(name_results, alias_results)
  end

  @doc """
  Searches glossary entries by word or definition.
  """
  @spec search_glossary(String.t()) :: [map()]
  def search_glossary(query) do
    search_term = "%#{query}%"

    from(g in Glossary,
      where: ilike(g.word, ^search_term) or ilike(g.definition, ^search_term),
      order_by: g.word,
      select: %{
        id: g.id,
        name: g.word,
        type: "glossary",
        definition: g.definition
      }
    )
    |> Repo.all()
  end

  @doc """
  Searches sources by title or author.
  """
  @spec search_sources(String.t()) :: [map()]
  def search_sources(query) do
    search_term = "%#{query}%"

    from(s in Source,
      where: ilike(s.title, ^search_term) or ilike(s.author, ^search_term),
      order_by: s.title,
      select: %{
        id: s.id,
        name: s.title,
        type: "source",
        author: s.author,
        pubyear: s.pubyear
      }
    )
    |> Repo.all()
  end

  @doc """
  Searches taxonomy entries (genus, family, section) by name.
  """
  @spec search_taxonomy(String.t()) :: [map()]
  def search_taxonomy(query) do
    search_term = "%#{query}%"

    from(t in Taxonomy,
      where:
        t.type in ["genus", "family", "section"] and
          ilike(t.name, ^search_term),
      order_by: [t.type, t.name],
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
  Searches places by name or code.
  """
  @spec search_places(String.t()) :: [map()]
  def search_places(query) do
    search_term = "%#{query}%"

    from(p in Place,
      where: ilike(p.name, ^search_term) or ilike(p.code, ^search_term),
      order_by: p.name,
      select: %{
        id: p.id,
        name: p.name,
        type: "place",
        code: p.code
      }
    )
    |> Repo.all()
  end

  # Merges species results with alias matches, deduplicating by ID
  defp merge_species_with_aliases(name_results, alias_results) do
    alias_map = build_alias_map(alias_results)
    name_ids = MapSet.new(name_results, & &1.id)

    alias_only_species =
      alias_results
      |> Enum.reject(fn r -> MapSet.member?(name_ids, r.id) end)
      |> Enum.uniq_by(& &1.id)
      |> Enum.map(&add_aliases_to_result(&1, alias_map))

    name_results_with_aliases = Enum.map(name_results, &add_aliases_to_result(&1, alias_map))

    name_results_with_aliases ++ alias_only_species
  end

  # Builds a map of species ID -> list of matching alias names
  defp build_alias_map(alias_results) do
    Enum.reduce(alias_results, %{}, fn result, acc ->
      add_alias_to_map(acc, result.id, result.alias_match)
    end)
  end

  defp add_alias_to_map(acc, id, alias_name) do
    Map.update(acc, id, [alias_name], &maybe_add_alias(&1, alias_name))
  end

  defp maybe_add_alias(aliases, alias_name) do
    if alias_name in aliases, do: aliases, else: [alias_name | aliases]
  end

  defp add_aliases_to_result(result, alias_map) do
    aliases = Map.get(alias_map, result.id, [])

    result
    |> Map.put(:aliases, aliases)
    |> Map.delete(:alias_match)
  end
end
