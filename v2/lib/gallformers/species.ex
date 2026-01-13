defmodule Gallformers.Species do
  @moduledoc """
  The Species context.

  Provides functions for working with species, including galls and hosts.
  """

  import Ecto.Query
  alias Gallformers.Repo
  alias Gallformers.Species.{Abundance, Gall, GallSpecies, Image, Species}

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
  Searches species by name or alias (case-insensitive).
  Supports multi-word queries.
  """
  @spec search_species(String.t(), integer()) :: [map()]
  def search_species(query, limit \\ 100) when is_binary(query) do
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

  @doc """
  Searches species by name (species only, no aliases).
  Used for typeahead when selecting hosts.
  """
  @spec search_species_by_name(String.t(), String.t() | nil, integer()) :: [map()]
  def search_species_by_name(query, taxoncode \\ nil, limit \\ 20) do
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
    %Species{}
    |> Species.changeset(attrs)
    |> Repo.insert()
    |> broadcast(:species_created)
  end

  @doc """
  Updates a species.
  """
  def update_species(%Species{} = species, attrs) do
    species
    |> Species.changeset(attrs)
    |> Repo.update()
    |> broadcast(:species_updated)
  end

  @doc """
  Deletes a species.
  """
  def delete_species(%Species{} = species) do
    Repo.delete(species)
    |> broadcast(:species_deleted)
  end

  # Alias management

  @doc """
  Creates an alias and associates it with a species.
  """
  def create_alias_for_species(species_id, alias_attrs) do
    alias Gallformers.Species.Alias

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
    |> broadcast(:species_updated)
  end

  @doc """
  Removes an alias from a species.
  """
  def remove_alias_from_species(species_id, alias_id) do
    from(als in "aliasspecies",
      where: als.species_id == ^species_id and als.alias_id == ^alias_id
    )
    |> Repo.delete_all()

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
end
