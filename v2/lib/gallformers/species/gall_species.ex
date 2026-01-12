defmodule Gallformers.Species.GallSpecies do
  @moduledoc """
  Ecto schema for the gallspecies join table.

  Links species to galls (many-to-many relationship).
  """
  use Ecto.Schema

  @primary_key false

  @type t :: %__MODULE__{
          species_id: integer(),
          gall_id: integer()
        }

  schema "gallspecies" do
    belongs_to :species, Gallformers.Species.Species, primary_key: true
    belongs_to :gall, Gallformers.Species.Gall, primary_key: true
  end
end
