defmodule Gallformers.Sources do
  @moduledoc """
  The Sources context.

  Provides functions for working with scientific references and citations.
  """

  import Ecto.Query
  alias Gallformers.Repo
  alias Gallformers.Sources.Source
  alias Gallformers.Species.SpeciesSource

  @doc """
  Returns all sources ordered by title.
  """
  @spec list_sources() :: [Source.t()]
  def list_sources do
    from(s in Source,
      order_by: s.title
    )
    |> Repo.all()
  end

  @doc """
  Returns paginated sources.
  """
  @spec list_sources_paginated(integer(), integer()) :: [Source.t()]
  def list_sources_paginated(limit, offset) do
    from(s in Source,
      order_by: s.title,
      limit: ^limit,
      offset: ^offset
    )
    |> Repo.all()
  end

  @doc """
  Returns the count of all sources.
  """
  @spec count_sources() :: integer()
  def count_sources do
    from(s in Source,
      select: count(s.id)
    )
    |> Repo.one()
  end

  @doc """
  Gets a source by ID.
  """
  @spec get_source(integer()) :: Source.t() | nil
  def get_source(id) do
    Repo.get(Source, id)
  end

  @doc """
  Gets a source by ID, raising if not found.
  """
  @spec get_source!(integer()) :: Source.t()
  def get_source!(id) do
    Repo.get!(Source, id)
  end

  @doc """
  Gets a source by title.
  """
  @spec get_source_by_title(String.t()) :: Source.t() | nil
  def get_source_by_title(title) do
    from(s in Source,
      where: s.title == ^title
    )
    |> Repo.one()
  end

  @doc """
  Searches sources by title or author.
  """
  @spec search_sources(String.t()) :: [Source.t()]
  def search_sources(query) do
    search_term = "%#{String.downcase(query)}%"

    from(s in Source,
      where:
        fragment("lower(?) LIKE ?", s.title, ^search_term) or
          fragment("lower(?) LIKE ?", s.author, ^search_term),
      order_by: s.title
    )
    |> Repo.all()
  end

  @doc """
  Gets all sources for a species.
  """
  @spec get_sources_for_species(integer()) :: [map()]
  def get_sources_for_species(species_id) do
    from(ss in SpeciesSource,
      join: s in Source,
      on: ss.source_id == s.id,
      where: ss.species_id == ^species_id,
      order_by: [desc: ss.useasdefault, asc: s.title],
      select: %{
        id: s.id,
        title: s.title,
        author: s.author,
        pubyear: s.pubyear,
        link: s.link,
        citation: s.citation,
        description: ss.description,
        useasdefault: ss.useasdefault,
        externallink: ss.externallink
      }
    )
    |> Repo.all()
  end

  @doc """
  Gets all species associated with a source.
  """
  @spec get_species_for_source(integer()) :: [map()]
  def get_species_for_source(source_id) do
    alias Gallformers.Species.Species

    from(ss in SpeciesSource,
      join: sp in Species,
      on: ss.species_id == sp.id,
      where: ss.source_id == ^source_id,
      order_by: sp.name,
      select: %{
        id: sp.id,
        name: sp.name,
        taxoncode: sp.taxoncode,
        description: ss.description,
        externallink: ss.externallink
      }
    )
    |> Repo.all()
  end

  @doc """
  Gets the count of species associated with a source.
  """
  @spec count_species_for_source(integer()) :: integer()
  def count_species_for_source(source_id) do
    from(ss in SpeciesSource,
      where: ss.source_id == ^source_id,
      select: count(ss.id)
    )
    |> Repo.one()
  end
end
