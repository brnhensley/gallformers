defmodule Gallformers.FilterFields.Walls do
  @moduledoc """
  Ecto schema for the walls table.

  Describes the wall structure of galls (e.g., "thin", "thick").
  """
  use Ecto.Schema
  import Ecto.Changeset
  import Gallformers.ChangesetHelpers, only: [trim_strings: 1]

  @type t :: %__MODULE__{
          id: integer() | nil,
          walls: String.t() | nil,
          description: String.t() | nil
        }

  schema "walls" do
    field :walls, :string
    field :description, :string
  end

  @doc false
  def changeset(walls, attrs) do
    walls
    |> cast(attrs, [:walls, :description])
    |> trim_strings()
    |> validate_required([:walls])
    |> unique_constraint(:walls)
  end
end
