defmodule Gallformers.FilterFields.Cells do
  @moduledoc """
  Ecto schema for the cells table.

  Describes the internal cell structure of galls (e.g., "monothalamous", "polythalamous").
  """
  use Ecto.Schema
  import Ecto.Changeset
  import Gallformers.ChangesetHelpers, only: [trim_strings: 1]

  @type t :: %__MODULE__{
          id: integer() | nil,
          cells: String.t() | nil,
          description: String.t() | nil
        }

  schema "cells" do
    field :cells, :string
    field :description, :string
  end

  @doc false
  def changeset(cells, attrs) do
    cells
    |> cast(attrs, [:cells, :description])
    |> trim_strings()
    |> validate_required([:cells])
    |> unique_constraint(:cells)
  end
end
