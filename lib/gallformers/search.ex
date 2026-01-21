defmodule Gallformers.Search do
  @moduledoc """
  The Search context.

  Provides functions for searching across species, hosts, and other entities.
  """

  import Ecto.Query

  alias Gallformers.Glossaries.Glossary
  alias Gallformers.Places.Place
  alias Gallformers.Repo
  alias Gallformers.Search.Ranking
  alias Gallformers.Sources.Source
  alias Gallformers.Species.{Alias, Gall, GallSpecies, Species}
  alias Gallformers.Taxonomy.Taxonomy

  @doc """
  Searches galls by name (partial match).
  Returns the same fields as Species.list_galls for API compatibility.
  """
  @spec search_galls(String.t()) :: [map()]
  def search_galls(query) do
    search_term = "%#{String.downcase(query)}%"

    from(s in Species,
      join: gs in GallSpecies,
      on: gs.species_id == s.id,
      join: g in Gall,
      on: gs.gall_id == g.id,
      left_join: a in Gallformers.Species.Abundance,
      on: s.abundance_id == a.id,
      where: s.taxoncode == "gall" and fragment("lower(?) LIKE ?", s.name, ^search_term),
      order_by: s.name,
      select: %{
        id: s.id,
        name: s.name,
        taxoncode: s.taxoncode,
        datacomplete: s.datacomplete,
        abundance_id: s.abundance_id,
        abundance_name: a.abundance,
        gall_id: g.id,
        detachable: g.detachable,
        undescribed: g.undescribed
      }
    )
    |> Repo.all()
  end

  @doc """
  Searches galls by name with pagination.
  Returns the same fields as Species.list_galls_paginated for API compatibility.
  """
  @spec search_galls_paginated(String.t(), integer(), integer()) :: [map()]
  def search_galls_paginated(query, limit, offset) do
    search_term = "%#{String.downcase(query)}%"

    from(s in Species,
      join: gs in GallSpecies,
      on: gs.species_id == s.id,
      join: g in Gall,
      on: gs.gall_id == g.id,
      left_join: a in Gallformers.Species.Abundance,
      on: s.abundance_id == a.id,
      where: s.taxoncode == "gall" and fragment("lower(?) LIKE ?", s.name, ^search_term),
      order_by: s.name,
      limit: ^limit,
      offset: ^offset,
      select: %{
        id: s.id,
        name: s.name,
        taxoncode: s.taxoncode,
        datacomplete: s.datacomplete,
        abundance_id: s.abundance_id,
        abundance_name: a.abundance,
        gall_id: g.id,
        detachable: g.detachable,
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
    search_term = "%#{String.downcase(query)}%"

    from(s in Species,
      join: gs in GallSpecies,
      on: gs.species_id == s.id,
      where: s.taxoncode == "gall" and fragment("lower(?) LIKE ?", s.name, ^search_term),
      select: count(s.id)
    )
    |> Repo.one()
  end

  @doc """
  Searches hosts by name (partial match).
  Returns fields expected by the host API controller.
  """
  @spec search_hosts(String.t()) :: [map()]
  def search_hosts(query) do
    search_term = "%#{String.downcase(query)}%"

    from(s in Species,
      where: s.taxoncode == "plant" and fragment("lower(?) LIKE ?", s.name, ^search_term),
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
  Searches hosts by name with pagination.
  Returns fields expected by the host API controller.
  """
  @spec search_hosts_paginated(String.t(), integer(), integer()) :: [map()]
  def search_hosts_paginated(query, limit, offset) do
    search_term = "%#{String.downcase(query)}%"

    from(s in Species,
      where: s.taxoncode == "plant" and fragment("lower(?) LIKE ?", s.name, ^search_term),
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
  Returns the count of hosts matching a search query.
  """
  @spec count_search_hosts(String.t()) :: integer()
  def count_search_hosts(query) do
    search_term = "%#{String.downcase(query)}%"

    from(s in Species,
      where: s.taxoncode == "plant" and fragment("lower(?) LIKE ?", s.name, ^search_term),
      select: count(s.id)
    )
    |> Repo.one()
  end

  @doc """
  Searches all species (galls and hosts) by name.
  """
  @spec search_all(String.t()) :: [map()]
  def search_all(query) do
    search_term = "%#{String.downcase(query)}%"

    from(s in Species,
      where: fragment("lower(?) LIKE ?", s.name, ^search_term),
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
      search_terms = Ranking.parse_query(trimmed)

      %{
        galls: search_galls_with_aliases(trimmed),
        hosts: search_hosts_with_aliases(trimmed),
        glossary: search_glossary(trimmed) |> Ranking.add_scores_and_sort(search_terms),
        sources: search_sources(trimmed) |> Ranking.add_scores_and_sort(search_terms),
        taxonomy: search_taxonomy(trimmed) |> Ranking.add_scores_and_sort(search_terms),
        places: search_places(trimmed) |> Ranking.add_scores_and_sort(search_terms)
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
  Searches galls by name or alias using FTS5 for fast prefix matching.
  Falls back to LIKE search for mid-word matches.
  """
  @spec search_galls_with_aliases(String.t()) :: [map()]
  def search_galls_with_aliases(query) do
    # Try FTS5 first for prefix matching
    fts_results = search_galls_fts(query)

    if Enum.empty?(fts_results) do
      # Fall back to LIKE for mid-word matches
      search_galls_with_aliases_like(query)
    else
      fts_results
    end
  end

  # FTS5-based gall search
  defp search_galls_fts(query) do
    sanitized = Gallformers.Species.sanitize_fts_query(query)

    if sanitized == "" do
      []
    else
      fts_query =
        sanitized
        |> String.split(~r/\s+/, trim: true)
        |> Enum.map_join(" ", &"#{&1}*")

      sql = """
      SELECT f.species_id, s.name, g.undescribed, f.aliases
      FROM species_fts f
      JOIN species s ON s.id = f.species_id
      JOIN gallspecies gs ON gs.species_id = s.id
      JOIN gall g ON g.id = gs.gall_id
      WHERE s.taxoncode = 'gall' AND species_fts MATCH ?
      ORDER BY bm25(species_fts)
      LIMIT 100
      """

      case Repo.query(sql, [fts_query]) do
        {:ok, %{rows: rows}} ->
          search_terms = Ranking.parse_query(query)

          rows
          |> Enum.map(&transform_gall_row(&1, query))
          |> Ranking.add_scores_and_sort(search_terms)

        {:error, _} ->
          []
      end
    end
  end

  # LIKE-based fallback for mid-word matches
  defp search_galls_with_aliases_like(query) do
    search_term = "%#{String.downcase(query)}%"
    search_terms = Ranking.parse_query(query)

    # Search by species name
    name_results =
      from(s in Species,
        join: gs in GallSpecies,
        on: gs.species_id == s.id,
        join: g in Gall,
        on: gs.gall_id == g.id,
        where: s.taxoncode == "gall" and fragment("lower(?) LIKE ?", s.name, ^search_term),
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
        where: s.taxoncode == "gall" and fragment("lower(?) LIKE ?", a.name, ^search_term),
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
    name_results
    |> merge_species_with_aliases(alias_results)
    |> Ranking.add_scores_and_sort(search_terms)
  end

  @doc """
  Searches hosts by name or alias using FTS5 for fast prefix matching.
  Falls back to LIKE search for mid-word matches.
  """
  @spec search_hosts_with_aliases(String.t()) :: [map()]
  def search_hosts_with_aliases(query) do
    # Try FTS5 first for prefix matching
    fts_results = search_hosts_fts(query)

    if Enum.empty?(fts_results) do
      # Fall back to LIKE for mid-word matches
      search_hosts_with_aliases_like(query)
    else
      fts_results
    end
  end

  # FTS5-based host search
  defp search_hosts_fts(query) do
    sanitized = Gallformers.Species.sanitize_fts_query(query)

    if sanitized == "" do
      []
    else
      fts_query =
        sanitized
        |> String.split(~r/\s+/, trim: true)
        |> Enum.map_join(" ", &"#{&1}*")

      sql = """
      SELECT f.species_id, s.name, f.aliases
      FROM species_fts f
      JOIN species s ON s.id = f.species_id
      WHERE s.taxoncode = 'plant' AND species_fts MATCH ?
      ORDER BY bm25(species_fts)
      LIMIT 100
      """

      case Repo.query(sql, [fts_query]) do
        {:ok, %{rows: rows}} ->
          search_terms = Ranking.parse_query(query)

          rows
          |> Enum.map(&transform_host_row(&1, query))
          |> Ranking.add_scores_and_sort(search_terms)

        {:error, _} ->
          []
      end
    end
  end

  # LIKE-based fallback for mid-word matches
  defp search_hosts_with_aliases_like(query) do
    search_term = "%#{String.downcase(query)}%"
    search_terms = Ranking.parse_query(query)

    # Search by species name
    name_results =
      from(s in Species,
        where: s.taxoncode == "plant" and fragment("lower(?) LIKE ?", s.name, ^search_term),
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
        where: s.taxoncode == "plant" and fragment("lower(?) LIKE ?", a.name, ^search_term),
        order_by: s.name,
        select: %{
          id: s.id,
          name: s.name,
          type: "host",
          alias_match: a.name
        }
      )
      |> Repo.all()

    name_results
    |> merge_species_with_aliases(alias_results)
    |> Ranking.add_scores_and_sort(search_terms)
  end

  defp transform_gall_row([id, name, undescribed, aliases], query) do
    search_lower = String.downcase(query)
    matching_aliases = find_matching_aliases(aliases, search_lower, name)

    %{id: id, name: name, type: "gall", undescribed: undescribed == 1, aliases: matching_aliases}
  end

  defp transform_host_row([id, name, aliases], query) do
    search_lower = String.downcase(query)
    matching_aliases = find_matching_aliases(aliases, search_lower, name)

    %{id: id, name: name, type: "host", aliases: matching_aliases}
  end

  # Finds aliases that match the search query from a space-separated alias string
  # Only returns matching aliases if name doesn't match (to show why result appeared)
  defp find_matching_aliases(nil, _search, _name), do: []
  defp find_matching_aliases("", _search, _name), do: []

  defp find_matching_aliases(aliases_str, search, name) do
    # If the name itself matches, don't show aliases
    if String.contains?(String.downcase(name), search) do
      []
    else
      # Find and deduplicate matching aliases
      aliases_str
      |> String.split(" ")
      |> Enum.filter(fn alias_name ->
        alias_name != "" and String.contains?(String.downcase(alias_name), search)
      end)
      |> Enum.uniq()
    end
  end

  @doc """
  Searches glossary entries by word or definition.
  """
  @spec search_glossary(String.t()) :: [map()]
  def search_glossary(query) do
    search_term = "%#{String.downcase(query)}%"

    from(g in Glossary,
      where:
        fragment("lower(?) LIKE ?", g.word, ^search_term) or
          fragment("lower(?) LIKE ?", g.definition, ^search_term),
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
    search_term = "%#{String.downcase(query)}%"

    from(s in Source,
      where:
        fragment("lower(?) LIKE ?", s.title, ^search_term) or
          fragment("lower(?) LIKE ?", s.author, ^search_term),
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
    search_term = "%#{String.downcase(query)}%"

    from(t in Taxonomy,
      where:
        t.type in ["genus", "family", "section"] and
          fragment("lower(?) LIKE ?", t.name, ^search_term),
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
    search_term = "%#{String.downcase(query)}%"

    from(p in Place,
      where:
        fragment("lower(?) LIKE ?", p.name, ^search_term) or
          fragment("lower(?) LIKE ?", p.code, ^search_term),
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
