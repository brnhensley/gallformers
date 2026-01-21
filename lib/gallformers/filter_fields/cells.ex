defmodule Gallformers.FilterFields.Cells do
  @moduledoc """
  Ecto schema for the cells table.

  Describes the internal cell structure of galls (e.g., "monothalamous", "polythalamous").
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          cells: String.t() | nil,
          description: String.t() | nil
        }

  schema "cells" do
    field :cells, :string
    field :description, :string

    many_to_many :galls, Gallformers.Species.Gall,
      join_through: "gallcells",
      join_keys: [cells_id: :id, gall_id: :id]
  end

  @doc false
  def changeset(cells, attrs) do
    cells
    |> cast(attrs, [:cells, :description])
    |> validate_required([:cells])
    |> unique_constraint(:cells)
  end
end
