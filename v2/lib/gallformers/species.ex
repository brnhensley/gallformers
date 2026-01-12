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
  """
  @spec get_default_gall_images() :: [map()]
  def get_default_gall_images do
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
end
