defmodule Gallformers.Places do
  @moduledoc """
  The Places context.

  Provides functions for working with geographic places (states, provinces, regions).
  """

  import Ecto.Query
  alias Gallformers.Places.Place
  alias Gallformers.Repo

  @doc """
  Returns all places (states/provinces) ordered by name.
  """
  @spec list_places() :: [Place.t()]
  def list_places do
    from(p in Place,
      where: p.type in ["state", "province"],
      order_by: p.name
    )
    |> Repo.all()
  end

  @doc """
  Gets a place by code.
  """
  @spec get_place_by_code(String.t()) :: Place.t() | nil
  def get_place_by_code(code) do
    from(p in Place,
      where: p.code == ^code
    )
    |> Repo.one()
  end

  @doc """
  Gets a place by ID.
  """
  @spec get_place(integer()) :: Place.t() | nil
  def get_place(id) do
    Repo.get(Place, id)
  end
end
