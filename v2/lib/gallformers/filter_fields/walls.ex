defmodule Gallformers.FilterFields.Walls do
  @moduledoc """
  Ecto schema for the walls table.

  Describes the wall structure of galls (e.g., "thin", "thick").
  """
  use Ecto.Schema

  @type t :: %__MODULE__{
          id: integer() | nil,
          walls: String.t() | nil,
          description: String.t() | nil
        }

  schema "walls" do
    field :walls, :string
    field :description, :string

    many_to_many :galls, Gallformers.Species.Gall,
      join_through: "gallwalls",
      join_keys: [walls_id: :id, gall_id: :id]
  end
end
