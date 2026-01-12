defmodule Gallformers.Species.Species do
  @moduledoc """
  Ecto schema for the species table.

  Species can be galls, hosts, or other organisms. This is the core entity
  that represents a taxon in the gallformers database.
  """
  use Ecto.Schema

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t() | nil,
          taxoncode: String.t() | nil,
          datacomplete: boolean()
        }

  schema "species" do
    field :name, :string
    field :taxoncode, :string
    field :datacomplete, :boolean, default: false

    has_many :images, Gallformers.Species.Image
    has_many :gall_species, Gallformers.Species.GallSpecies
  end
end
