defmodule Gallformers.Species.SpeciesSource do
  @moduledoc """
  Ecto schema for the speciessource table.

  Links species to sources with additional metadata about the reference.
  """
  use Ecto.Schema

  @type t :: %__MODULE__{
          id: integer() | nil,
          species_id: integer() | nil,
          source_id: integer() | nil,
          description: String.t() | nil,
          useasdefault: integer(),
          externallink: String.t() | nil,
          alias_id: integer() | nil
        }

  schema "speciessource" do
    field :description, :string, default: ""
    field :useasdefault, :integer, default: 0
    field :externallink, :string, default: ""

    belongs_to :species, Gallformers.Species.Species
    belongs_to :source, Gallformers.Sources.Source
    belongs_to :alias, Gallformers.Species.Alias
  end
end
