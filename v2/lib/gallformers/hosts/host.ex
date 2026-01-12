defmodule Gallformers.Hosts.Host do
  @moduledoc """
  Ecto schema for the host table.

  Represents the relationship between a gall species and a host plant species.
  This is the join table that links gall-forming organisms to their host plants.
  """
  use Ecto.Schema

  @type t :: %__MODULE__{
          id: integer() | nil,
          host_species_id: integer() | nil,
          gall_species_id: integer() | nil
        }

  schema "host" do
    belongs_to :host_species, Gallformers.Species.Species, foreign_key: :host_species_id
    belongs_to :gall_species, Gallformers.Species.Species, foreign_key: :gall_species_id
  end
end
