defmodule Gallformers.FilterFields.Location do
  @moduledoc """
  Ecto schema for the location table.

  Locations on the host plant where galls can be found (e.g., "leaf", "stem", "bud").
  """
  use Ecto.Schema

  @type t :: %__MODULE__{
          id: integer() | nil,
          location: String.t() | nil,
          description: String.t() | nil
        }

  schema "location" do
    field :location, :string
    field :description, :string

    many_to_many :galls, Gallformers.Species.Gall,
      join_through: "galllocation",
      join_keys: [location_id: :id, gall_id: :id]
  end
end
