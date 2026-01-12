defmodule Gallformers.FilterFields.Color do
  @moduledoc """
  Ecto schema for the color table.

  Colors that can be associated with galls for identification.
  """
  use Ecto.Schema

  @type t :: %__MODULE__{
          id: integer() | nil,
          color: String.t() | nil
        }

  schema "color" do
    field :color, :string

    many_to_many :galls, Gallformers.Species.Gall,
      join_through: "gallcolor",
      join_keys: [color_id: :id, gall_id: :id]
  end
end
