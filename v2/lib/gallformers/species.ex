defmodule Gallformers.Species do
  @moduledoc """
  The Species context.

  Provides functions for working with species, including galls and hosts.
  """

  import Ecto.Query
  alias Gallformers.Repo
  alias Gallformers.Species.{Abundance, Gall, GallSpecies, Image, Species}
  alias Gallformers.Search.Ranking

  @doc """
  Returns a random gall that has a default image.

  Used on the home page to show a featured gall. Returns a map with:
    - id: species ID
    - name: species name
    - undescribed: whether the gall is undescribed
    - image_url: full CloudFront URL
    - image_creator: photographer credit
    - image_license: license name

  Returns `nil` if no galls with images are found.
  """
  @spec random_gall() :: map() | nil
  def random_gall do
    query =
      from g in Gall,
        join: gs in GallSpecies,
        on: gs.gall_id == g.id,
        join: s in Species,
        on: gs.species_id == s.id,
        join: i in Image,
        on: i.species_id == s.id,
        where: i.default == true,
        order_by: fragment("RANDOM()"),
        limit: 1,
        select: %{
          id: s.id,
          name: s.name,
          undescribed: g.undescribed,
          image_path: i.path,
          image_creator: i.creator,
          image_license: i.license
        }

    case Repo.one(query) do
      nil ->
        nil

      result ->
        Map.put(result, :image_url, Image.base_url() <> "/" <> result.image_path)
    end
  end

  @doc """
  Returns all species.
  """
  @spec list_species() :: [Species.t()]
  def list_species do
    Repo.all(Species)
  end

  @doc """
  Returns all gall species ordered by name.
  """
  @spec list_galls() :: [map()]
  def list_galls do
    from(s in Species,
      join: gs in GallSpecies,
      on: gs.species_id == s.id,
      join: g in Gall,
      on: gs.gall_id == g.id,
      left_join: a in Abundance,
      on: s.abundance_id == a.id,
      where: s.taxoncode == "gall",
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
  Returns paginated gall species.
  """
  @spec list_galls_paginated(integer(), integer()) :: [map()]
  def list_galls_paginated(limit, offset) do
    from(s in Species,
      join: gs in GallSpecies,
      on: gs.species_id == s.id,
      join: g in Gall,
      on: gs.gall_id == g.id,
      left_join: a in Abundance,
      on: s.abundance_id == a.id,
      where: s.taxoncode == "gall",
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
  Returns the count of all gall species.
  """
  @spec count_galls() :: integer()
  def count_galls do
    from(s in Species,
      where: s.taxoncode == "gall",
      select: count(s.id)
    )
    |> Repo.one()
  end

  @doc """
  Gets a single species by ID.
  """
  @spec get_species(integer()) :: Species.t() | nil
  def get_species(id) do
    Repo.get(Species, id)
  end

  @doc """
  Gets a single species by ID, raising if not found.
  """
  @spec get_species!(integer()) :: Species.t()
  def get_species!(id) do
    Repo.get!(Species, id)
  end

  @doc """
  Gets a gall by species ID with all related data.
  """
  @spec get_gall_by_id(integer()) :: map() | nil
  def get_gall_by_id(id) do
    query =
      from s in Species,
        join: gs in GallSpecies,
        on: gs.species_id == s.id,
        join: g in Gall,
        on: gs.gall_id == g.id,
        left_join: a in Abundance,
        on: s.abundance_id == a.id,
        where: s.id == ^id and s.taxoncode == "gall",
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

    Repo.one(query)
  end

  @doc """
  Gets a gall by species name.
  """
  @spec get_gall_by_name(String.t()) :: map() | nil
  def get_gall_by_name(name) do
    query =
      from s in Species,
        join: gs in GallSpecies,
        on: gs.species_id == s.id,
        join: g in Gall,
        on: gs.gall_id == g.id,
        left_join: a in Abundance,
        on: s.abundance_id == a.id,
        where: s.name == ^name and s.taxoncode == "gall",
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

    Repo.one(query)
  end

  @doc """
  Gets all images for a species, with default image first.
  """
  @spec get_images_for_species(integer()) :: [map()]
  def get_images_for_species(species_id) do
    from(i in Image,
      left_join: src in assoc(i, :source),
      where: i.species_id == ^species_id,
      order_by: [desc: i.default, asc: src.title, asc: i.id],
      select: %{
        id: i.id,
        path: i.path,
        default: i.default,
        creator: i.creator,
        attribution: i.attribution,
        sourcelink: i.sourcelink,
        license: i.license,
        licenselink: i.licenselink,
        caption: i.caption,
        source_title: src.title
      }
    )
    |> Repo.all()
  end

  @doc """
  Gets default images for all gall species (used by ID tool).

  Returns the default image for each species if one is set,
  otherwise returns the first image for that species.
  """
  @spec get_default_gall_images() :: [map()]
  def get_default_gall_images do
    # First, get all default images
    default_images =
      from(i in Image,
        join: s in Species,
        on: i.species_id == s.id,
        where: s.taxoncode == "gall" and i.default == true,
        select: %{
          species_id: i.species_id,
          path: i.path
        }
      )
      |> Repo.all()

    default_species_ids = Enum.map(default_images, & &1.species_id) |> MapSet.new()

    # Then get first image for species without a default
    # Use a subquery to get the minimum image id per species
    fallback_images =
      from(i in Image,
        join: s in Species,
        on: i.species_id == s.id,
        where: s.taxoncode == "gall" and i.species_id not in ^MapSet.to_list(default_species_ids),
        group_by: i.species_id,
        select: %{
          species_id: i.species_id,
          id: min(i.id)
        }
      )
      |> Repo.all()

    # Get the actual paths for fallback images
    fallback_image_ids = Enum.map(fallback_images, & &1.id)

    fallback_with_paths =
      if fallback_image_ids != [] do
        from(i in Image,
          where: i.id in ^fallback_image_ids,
          select: %{
            species_id: i.species_id,
            path: i.path
          }
        )
        |> Repo.all()
      else
        []
      end

    default_images ++ fallback_with_paths
  end

  @doc """
  Gets aliases for a species.
  """
  @spec get_aliases_for_species(integer()) :: [map()]
  def get_aliases_for_species(species_id) do
    alias Gallformers.Species.Alias

    from(a in Alias,
      join: als in "aliasspecies",
      on: als.alias_id == a.id,
      where: als.species_id == ^species_id,
      select: %{
        id: a.id,
        name: a.name,
        type: a.type,
        description: a.description
      }
    )
    |> Repo.all()
  end

  @doc """
  Returns all abundance options.
  """
  @spec list_abundances() :: [Abundance.t()]
  def list_abundances do
    Repo.all(Abundance)
  end

  @doc """
  Gets an abundance by ID.
  """
  @spec get_abundance(integer()) :: Abundance.t() | nil
  def get_abundance(id) do
    Repo.get(Abundance, id)
  end

  # Admin functions

  @doc """
  Lists all species with basic info for admin listing.
  Includes species name, taxoncode, abundance, and datacomplete status.
  """
  @spec list_species_admin(integer(), integer()) :: [map()]
  def list_species_admin(limit, offset) do
    from(s in Species,
      left_join: a in Abundance,
      on: s.abundance_id == a.id,
      order_by: s.name,
      limit: ^limit,
      offset: ^offset,
      select: %{
        id: s.id,
        name: s.name,
        taxoncode: s.taxoncode,
        datacomplete: s.datacomplete,
        abundance_name: a.abundance
      }
    )
    |> Repo.all()
  end

  @doc """
  Counts all species.
  """
  @spec count_species() :: integer()
  def count_species do
    from(s in Species, select: count(s.id))
    |> Repo.one()
  end

  @doc """
  Searches species by name or alias using FTS5 for fast prefix matching.
  Falls back to LIKE search for mid-word matches that FTS5 misses.

  This is the primary search function - it tries FTS5 first for speed
  and relevance ranking, then falls back to LIKE for edge cases.
  """
  @spec search_species(String.t(), integer()) :: [map()]
  def search_species(query, limit \\ 100) when is_binary(query) do
    fts_results = search_species_fts(query, limit)

    if Enum.empty?(fts_results) do
      # Fall back to LIKE for mid-word matches
      search_species_like_impl(query, limit)
    else
      fts_results
    end
  end

  # LIKE-based search implementation (fallback for mid-word matches)
  defp search_species_like_impl(query, limit) do
    terms =
      query
      |> String.downcase()
      |> String.split(~r/\s+/, trim: true)
      |> Enum.map(&"%#{&1}%")

    if terms == [] do
      []
    else
      search_species_with_terms(terms, limit)
    end
  end

  defp search_species_with_terms(terms, limit) do
    base_query =
      from(s in Species,
        left_join: als in "aliasspecies",
        on: als.species_id == s.id,
        left_join: a in "alias",
        on: a.id == als.alias_id,
        left_join: ab in Abundance,
        on: s.abundance_id == ab.id,
        group_by: [s.id, s.name, s.taxoncode, s.datacomplete, ab.abundance],
        order_by: s.name,
        limit: ^limit,
        select: %{
          id: s.id,
          name: s.name,
          taxoncode: s.taxoncode,
          datacomplete: s.datacomplete,
          abundance_name: ab.abundance
        }
      )

    # Add WHERE clause for each search term (all must match)
    Enum.reduce(terms, base_query, fn term, q ->
      from([s, als, a, ab] in q,
        where:
          fragment("lower(?) LIKE ?", s.name, ^term) or
            fragment("lower(?) LIKE ?", a.name, ^term)
      )
    end)
    |> Repo.all()
  end

  # ============================================
  # FTS5 Full-Text Search Functions
  # ============================================

  @doc """
  Searches species using FTS5 full-text search with bm25() ranking.

  Supports prefix matching (e.g., "qu alba" matches "Quercus alba").
  Returns results ranked by relevance.
  """
  @spec search_species_fts(String.t(), integer()) :: [map()]
  def search_species_fts(query, limit \\ 100) when is_binary(query) do
    sanitized = sanitize_fts_query(query)

    if sanitized == "" do
      []
    else
      # Add * suffix to each term for prefix matching
      search_terms = Ranking.parse_query(sanitized)
      fts_query = search_terms |> Enum.map(&"#{&1}*") |> Enum.join(" ")

      sql = """
      SELECT f.species_id, s.name, s.taxoncode, s.datacomplete, a.abundance as abundance_name
      FROM species_fts f
      JOIN species s ON s.id = f.species_id
      LEFT JOIN abundance a ON s.abundance_id = a.id
      WHERE species_fts MATCH ?
      ORDER BY bm25(species_fts)
      LIMIT ?
      """

      case Repo.query(sql, [fts_query, limit]) do
        {:ok, %{rows: rows}} ->
          rows
          |> Enum.map(fn [id, name, taxoncode, datacomplete, abundance_name] ->
            %{
              id: id,
              name: name,
              taxoncode: taxoncode,
              datacomplete: datacomplete == 1,
              abundance_name: abundance_name
            }
          end)
          |> Ranking.add_scores_and_sort(search_terms)

        {:error, _} ->
          []
      end
    end
  end

  @doc """
  Searches species using LIKE for mid-word matches.

  Use this directly when you specifically need LIKE matching
  (e.g., searching for a substring in the middle of a name).
  """
  @spec search_species_like(String.t(), integer()) :: [map()]
  def search_species_like(query, limit \\ 100) when is_binary(query) do
    search_species_like_impl(query, limit)
  end

  @doc """
  Sanitizes a query string for FTS5 MATCH syntax.

  Escapes special FTS5 characters: - " * : ^ ( )
  """
  @spec sanitize_fts_query(String.t()) :: String.t()
  def sanitize_fts_query(query) when is_binary(query) do
    query
    |> String.replace(~r/["\-*:^()]+/, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  @doc """
  Updates the FTS index entry for a single species.

  Call this after updating a species name or aliases.
  """
  @spec update_species_fts(integer()) :: :ok | {:error, any()}
  def update_species_fts(species_id) do
    # Execute as two separate statements since SQLite doesn't support multiple
    # statements in a single query
    with {:ok, _} <- Repo.query("DELETE FROM species_fts WHERE species_id = ?", [species_id]),
         {:ok, _} <-
           Repo.query(
             """
             INSERT INTO species_fts(species_id, name, aliases)
             SELECT s.id, s.name, COALESCE(GROUP_CONCAT(a.name, ' '), '')
             FROM species s
             LEFT JOIN aliasspecies als ON als.species_id = s.id
             LEFT JOIN alias a ON a.id = als.alias_id
             WHERE s.id = ?
             GROUP BY s.id
             """,
             [species_id]
           ) do
      :ok
    end
  end

  @doc """
  Removes a species from the FTS index.

  Call this before deleting a species.
  """
  @spec delete_species_fts(integer()) :: :ok | {:error, any()}
  def delete_species_fts(species_id) do
    case Repo.query("DELETE FROM species_fts WHERE species_id = ?", [species_id]) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Rebuilds the entire FTS index from scratch.

  Use this for maintenance or after bulk data changes.
  """
  @spec rebuild_species_fts() :: :ok | {:error, any()}
  def rebuild_species_fts do
    with {:ok, _} <- Repo.query("DELETE FROM species_fts", []),
         {:ok, _} <-
           Repo.query(
             """
             INSERT INTO species_fts(species_id, name, aliases)
             SELECT s.id, s.name, COALESCE(GROUP_CONCAT(a.name, ' '), '')
             FROM species s
             LEFT JOIN aliasspecies als ON als.species_id = s.id
             LEFT JOIN alias a ON a.id = als.alias_id
             GROUP BY s.id
             """,
             []
           ) do
      :ok
    end
  end

  @doc """
  Searches species by name using FTS5 for fast prefix matching.
  Used for typeahead when selecting hosts.

  Falls back to LIKE search for mid-word matches.
  """
  @spec search_species_by_name(String.t(), String.t() | nil, integer()) :: [map()]
  def search_species_by_name(query, taxoncode \\ nil, limit \\ 20) do
    fts_results = search_species_by_name_fts(query, taxoncode, limit)

    if Enum.empty?(fts_results) do
      search_species_by_name_like(query, taxoncode, limit)
    else
      fts_results
    end
  end

  # FTS5-based name search with optional taxoncode filter
  defp search_species_by_name_fts(query, taxoncode, limit) do
    sanitized = sanitize_fts_query(query)

    if sanitized == "" do
      []
    else
      fts_query =
        sanitized
        |> String.split(~r/\s+/, trim: true)
        |> Enum.map(&"#{&1}*")
        |> Enum.join(" ")

      # Build SQL with optional taxoncode filter
      {sql, params} =
        if taxoncode do
          {"""
           SELECT f.species_id, s.name, s.taxoncode
           FROM species_fts f
           JOIN species s ON s.id = f.species_id
           WHERE species_fts MATCH ? AND s.taxoncode = ?
           ORDER BY bm25(species_fts)
           LIMIT ?
           """, [fts_query, taxoncode, limit]}
        else
          {"""
           SELECT f.species_id, s.name, s.taxoncode
           FROM species_fts f
           JOIN species s ON s.id = f.species_id
           WHERE species_fts MATCH ?
           ORDER BY bm25(species_fts)
           LIMIT ?
           """, [fts_query, limit]}
        end

      case Repo.query(sql, params) do
        {:ok, %{rows: rows}} ->
          Enum.map(rows, fn [id, name, tc] ->
            %{id: id, name: name, taxoncode: tc}
          end)

        {:error, _} ->
          []
      end
    end
  end

  # LIKE-based fallback for mid-word matches
  defp search_species_by_name_like(query, taxoncode, limit) do
    search_term = "%#{String.downcase(query)}%"

    base_query =
      from(s in Species,
        where: fragment("lower(?) LIKE ?", s.name, ^search_term),
        order_by: s.name,
        limit: ^limit,
        select: %{
          id: s.id,
          name: s.name,
          taxoncode: s.taxoncode
        }
      )

    query =
      if taxoncode do
        from(s in base_query, where: s.taxoncode == ^taxoncode)
      else
        base_query
      end

    Repo.all(query)
  end

  @doc """
  Gets a species for editing with all related data.
  """
  @spec get_species_for_edit(integer()) :: map() | nil
  def get_species_for_edit(id) do
    species = get_species(id)

    if species do
      aliases = get_aliases_for_species(id)
      hosts = Gallformers.Hosts.get_hosts_for_gall(id)
      taxonomy = Gallformers.Taxonomy.get_taxonomy_for_species(id)

      %{
        species: species,
        aliases: aliases,
        hosts: hosts,
        taxonomy: taxonomy
      }
    else
      nil
    end
  end

  @doc """
  Returns a changeset for tracking species changes.
  """
  def change_species(%Species{} = species, attrs \\ %{}) do
    Species.changeset(species, attrs)
  end

  @doc """
  Creates a species.
  """
  def create_species(attrs \\ %{}) do
    result =
      %Species{}
      |> Species.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, species} ->
        update_species_fts(species.id)
        broadcast(result, :species_created)

      {:error, _} ->
        result
    end
  end

  @doc """
  Updates a species.
  """
  def update_species(%Species{} = species, attrs) do
    result =
      species
      |> Species.changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, updated_species} ->
        update_species_fts(updated_species.id)
        broadcast(result, :species_updated)

      {:error, _} ->
        result
    end
  end

  @doc """
  Checks if a species name already exists.
  """
  @spec species_name_exists?(String.t()) :: boolean()
  def species_name_exists?(name) do
    from(s in Species, where: s.name == ^name)
    |> Repo.exists?()
  end

  @doc """
  Renames a species, optionally adding the old name as a scientific synonym alias.

  This handles the complex rename logic including potential genus reassignment.
  If the genus part of the name changes, the species may need to be reassigned
  to a different genus (or a new genus created).

  Returns {:ok, species} on success, {:error, reason} on failure.
  """
  @spec rename_species(integer(), String.t(), boolean()) ::
          {:ok, Species.t()} | {:error, atom() | String.t()}
  def rename_species(species_id, new_name, add_alias?) do
    if species_name_exists?(new_name) do
      {:error, :name_exists}
    else
      do_rename_species(species_id, new_name, add_alias?)
    end
  end

  defp do_rename_species(species_id, new_name, add_alias?) do
    species = get_species!(species_id)
    old_name = species.name

    Repo.transaction(fn ->
      if add_alias?, do: add_rename_alias(species_id, old_name)

      species
      |> Species.changeset(%{name: new_name})
      |> Repo.update!()
    end)
  end

  defp add_rename_alias(species_id, old_name) do
    alias Gallformers.Species.Alias

    alias_changeset =
      %Alias{}
      |> Ecto.Changeset.cast(
        %{name: old_name, type: "scientific synonym", description: "Previous name"},
        [:name, :type, :description]
      )

    case Repo.insert(alias_changeset) do
      {:ok, new_alias} ->
        Repo.insert_all("aliasspecies", [%{alias_id: new_alias.id, species_id: species_id}])

      {:error, _} ->
        nil
    end
  end

  @doc """
  Deletes a species.
  """
  def delete_species(%Species{} = species) do
    # Delete from FTS index first
    delete_species_fts(species.id)

    Repo.delete(species)
    |> broadcast(:species_deleted)
  end

  # Alias management

  @doc """
  Creates an alias and associates it with a species.
  """
  def create_alias_for_species(species_id, alias_attrs) do
    alias Gallformers.Species.Alias

    result =
      Repo.transaction(fn ->
        # Create the alias
        alias_changeset =
          %Alias{}
          |> Ecto.Changeset.cast(alias_attrs, [:name, :type, :description])
          |> Ecto.Changeset.validate_required([:name, :type])

        case Repo.insert(alias_changeset) do
          {:ok, new_alias} ->
            # Link to species
            Repo.insert_all("aliasspecies", [
              %{alias_id: new_alias.id, species_id: species_id}
            ])

            new_alias

          {:error, changeset} ->
            Repo.rollback(changeset)
        end
      end)

    # Update FTS index after alias is added
    case result do
      {:ok, _} -> update_species_fts(species_id)
      _ -> :ok
    end

    broadcast(result, :species_updated)
  end

  @doc """
  Removes an alias from a species.
  """
  def remove_alias_from_species(species_id, alias_id) do
    from(als in "aliasspecies",
      where: als.species_id == ^species_id and als.alias_id == ^alias_id
    )
    |> Repo.delete_all()

    # Update FTS index after alias is removed
    update_species_fts(species_id)

    broadcast({:ok, %{id: species_id}}, :species_updated)
  end

  # Host association management

  @doc """
  Associates a host with a gall species.
  """
  def add_host_to_species(gall_species_id, host_species_id) do
    alias Gallformers.Hosts.Host

    attrs = %{gall_species_id: gall_species_id, host_species_id: host_species_id}

    case %Host{} |> Host.changeset(attrs) |> Repo.insert() do
      {:ok, host_relation} ->
        broadcast({:ok, %{id: gall_species_id}}, :species_updated)
        {:ok, host_relation}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Removes a host association from a gall species.
  """
  def remove_host_from_species(host_relation_id) do
    alias Gallformers.Hosts.Host

    case Repo.get(Host, host_relation_id) do
      nil ->
        {:error, :not_found}

      host_relation ->
        species_id = host_relation.gall_species_id
        Repo.delete(host_relation)
        broadcast({:ok, %{id: species_id}}, :species_updated)
    end
  end

  @doc """
  Subscribes to species changes.
  """
  def subscribe do
    Phoenix.PubSub.subscribe(Gallformers.PubSub, "species")
  end

  defp broadcast({:ok, species}, event) do
    Phoenix.PubSub.broadcast(Gallformers.PubSub, "species", {event, species})
    {:ok, species}
  end

  defp broadcast({:error, changeset}, _event) do
    {:error, changeset}
  end

  # ============================================
  # Gall-specific functions for admin
  # ============================================

  @doc """
  Gets a gall for editing with all filter field values.
  Returns a map with gall data and current filter selections.
  """
  @spec get_gall_for_admin_edit(integer()) :: map() | nil
  def get_gall_for_admin_edit(species_id) do
    gall_data = get_gall_by_id(species_id)

    if gall_data do
      # Get all current filter field values for this gall
      gall_id = gall_data.gall_id
      filter_values = get_gall_filter_values(gall_id)

      Map.merge(gall_data, %{
        filter_values: filter_values
      })
    else
      nil
    end
  end

  @doc """
  Gets all filter field values for a gall as maps with :id and :field keys.
  """
  @spec get_gall_filter_values(integer()) :: map()
  def get_gall_filter_values(gall_id) do
    %{
      colors:
        get_filter_values_for_gall(
          gall_id,
          "gallcolor",
          "color_id",
          Gallformers.FilterFields.Color,
          :color
        ),
      shapes:
        get_filter_values_for_gall(
          gall_id,
          "gallshape",
          "shape_id",
          Gallformers.FilterFields.Shape,
          :shape
        ),
      textures:
        get_filter_values_for_gall(
          gall_id,
          "galltexture",
          "texture_id",
          Gallformers.FilterFields.Texture,
          :texture
        ),
      alignments:
        get_filter_values_for_gall(
          gall_id,
          "gallalignment",
          "alignment_id",
          Gallformers.FilterFields.Alignment,
          :alignment
        ),
      walls:
        get_filter_values_for_gall(
          gall_id,
          "gallwalls",
          "walls_id",
          Gallformers.FilterFields.Walls,
          :walls
        ),
      cells:
        get_filter_values_for_gall(
          gall_id,
          "gallcells",
          "cells_id",
          Gallformers.FilterFields.Cells,
          :cells
        ),
      locations:
        get_filter_values_for_gall(
          gall_id,
          "galllocation",
          "location_id",
          Gallformers.FilterFields.Location,
          :location
        ),
      forms:
        get_filter_values_for_gall(
          gall_id,
          "gallform",
          "form_id",
          Gallformers.FilterFields.Form,
          :form
        ),
      seasons:
        get_filter_values_for_gall(
          gall_id,
          "gallseason",
          "season_id",
          Gallformers.FilterFields.Season,
          :season
        )
    }
  end

  defp get_filter_values_for_gall(gall_id, join_table, fk_column, schema, field) do
    fk_col = String.to_atom(fk_column)

    from(j in join_table,
      join: s in ^schema,
      on: field(j, ^fk_col) == s.id,
      where: j.gall_id == ^gall_id,
      select: %{id: s.id, field: field(s, ^field)}
    )
    |> Repo.all()
  end

  @doc """
  Updates gall properties (detachable, undescribed).
  """
  @spec update_gall_properties(integer(), map()) :: {:ok, Gall.t()} | {:error, Ecto.Changeset.t()}
  def update_gall_properties(gall_id, attrs) do
    case Repo.get(Gall, gall_id) do
      nil ->
        {:error, :not_found}

      gall ->
        gall
        |> Ecto.Changeset.change(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Adds a filter field to a gall.
  """
  @spec add_filter_field_to_gall(integer(), atom(), integer()) :: {:ok, any()} | {:error, any()}
  def add_filter_field_to_gall(gall_id, filter_type, filter_id) do
    {join_table, fk_column} = get_join_table_info(filter_type)
    fk_col = String.to_atom(fk_column)
    row = Map.new([{:gall_id, gall_id}, {fk_col, filter_id}])

    try do
      Repo.insert_all(join_table, [row])
      {:ok, :inserted}
    rescue
      e in Ecto.ConstraintError ->
        {:error, e}
    end
  end

  @doc """
  Removes a filter field from a gall.
  """
  @spec remove_filter_field_from_gall(integer(), atom(), integer()) :: {:ok, integer()}
  def remove_filter_field_from_gall(gall_id, filter_type, filter_id) do
    {join_table, fk_column} = get_join_table_info(filter_type)
    fk_col = String.to_atom(fk_column)

    {count, _} =
      from(j in join_table,
        where: j.gall_id == ^gall_id and field(j, ^fk_col) == ^filter_id
      )
      |> Repo.delete_all()

    {:ok, count}
  end

  defp get_join_table_info(:colors), do: {"gallcolor", "color_id"}
  defp get_join_table_info(:shapes), do: {"gallshape", "shape_id"}
  defp get_join_table_info(:textures), do: {"galltexture", "texture_id"}
  defp get_join_table_info(:alignments), do: {"gallalignment", "alignment_id"}
  defp get_join_table_info(:walls), do: {"gallwalls", "walls_id"}
  defp get_join_table_info(:cells), do: {"gallcells", "cells_id"}
  defp get_join_table_info(:locations), do: {"galllocation", "location_id"}
  defp get_join_table_info(:forms), do: {"gallform", "form_id"}
  defp get_join_table_info(:seasons), do: {"gallseason", "season_id"}

  @doc """
  Returns all filter field options for gall admin.
  """
  @spec get_all_filter_options() :: map()
  def get_all_filter_options do
    %{
      colors:
        Gallformers.FilterFields.list_all(:color) |> Enum.map(&%{id: &1.id, field: &1.color}),
      shapes:
        Gallformers.FilterFields.list_all(:shape) |> Enum.map(&%{id: &1.id, field: &1.shape}),
      textures:
        Gallformers.FilterFields.list_all(:texture) |> Enum.map(&%{id: &1.id, field: &1.texture}),
      alignments:
        Gallformers.FilterFields.list_all(:alignment)
        |> Enum.map(&%{id: &1.id, field: &1.alignment}),
      walls:
        Gallformers.FilterFields.list_all(:walls) |> Enum.map(&%{id: &1.id, field: &1.walls}),
      cells:
        Gallformers.FilterFields.list_all(:cells) |> Enum.map(&%{id: &1.id, field: &1.cells}),
      locations:
        Gallformers.FilterFields.list_all(:location)
        |> Enum.map(&%{id: &1.id, field: &1.location}),
      forms: Gallformers.FilterFields.list_all(:form) |> Enum.map(&%{id: &1.id, field: &1.form}),
      seasons: get_all_seasons()
    }
  end

  defp get_all_seasons do
    from(s in Gallformers.FilterFields.Season,
      order_by: s.id,
      select: %{id: s.id, field: s.season}
    )
    |> Repo.all()
  end
end
