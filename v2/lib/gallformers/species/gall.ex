defmodule Gallformers.Species.Gall do
  @moduledoc """
  Ecto schema for the gall table.

  Galls are abnormal plant growths caused by insects, mites, or other organisms.
  This schema captures the gall-specific attributes separate from the species data.
  """
  use Ecto.Schema

  @type t :: %__MODULE__{
          id: integer() | nil,
          taxoncode: String.t() | nil,
          detachable: integer() | nil,
          undescribed: boolean()
        }

  schema "gall" do
    field :taxoncode, :string
    field :detachable, :integer
    field :undescribed, :boolean, default: false

    has_many :gall_species, Gallformers.Species.GallSpecies
  end
end
