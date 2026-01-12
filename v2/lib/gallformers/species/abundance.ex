defmodule Gallformers.Species.Abundance do
  @moduledoc """
  Ecto schema for the abundance table.

  Describes how common a species is (e.g., "common", "rare", "uncommon").
  """
  use Ecto.Schema

  @type t :: %__MODULE__{
          id: integer() | nil,
          abundance: String.t() | nil,
          description: String.t() | nil,
          reference: String.t() | nil
        }

  schema "abundance" do
    field :abundance, :string
    field :description, :string
    field :reference, :string

    has_many :species, Gallformers.Species.Species
  end
end
