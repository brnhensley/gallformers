defmodule Gallformers.FilterFields.Color do
  @moduledoc """
  Ecto schema for the color table.

  Colors that can be associated with galls for identification.
  """
  use Ecto.Schema
  import Ecto.Changeset
  import Gallformers.ChangesetHelpers, only: [trim_strings: 1]

  @type t :: %__MODULE__{
          id: integer() | nil,
          color: String.t() | nil
        }

  schema "color" do
    field :color, :string
  end

  @doc false
  def changeset(color, attrs) do
    color
    |> cast(attrs, [:color])
    |> trim_strings()
    |> validate_required([:color])
    |> unique_constraint(:color)
  end
end
