defmodule Gallformers.Species.TaxonType do
  @moduledoc """
  Ecto schema for the taxontype table.

  Defines the type of taxon (e.g., "gall", "host", "parasitoid").
  The taxoncode is the primary key.
  """
  use Ecto.Schema

  @primary_key {:taxoncode, :string, autogenerate: false}

  @type t :: %__MODULE__{
          taxoncode: String.t() | nil,
          description: String.t() | nil
        }

  schema "taxontype" do
    field :description, :string

    has_many :species, Gallformers.Species.Species,
      foreign_key: :taxoncode,
      references: :taxoncode

    has_many :galls, Gallformers.Species.Gall, foreign_key: :taxoncode, references: :taxoncode
  end
end
