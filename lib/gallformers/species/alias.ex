defmodule Gallformers.Species.Alias do
  @moduledoc """
  Ecto schema for the alias table.

  Represents alternative names for species (synonyms, common names, etc.).
  """
  use Ecto.Schema

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t() | nil,
          type: String.t() | nil,
          description: String.t() | nil
        }

  schema "alias" do
    field :name, :string
    field :type, :string
    field :description, :string, default: ""

    many_to_many :species, Gallformers.Species.Species,
      join_through: "aliasspecies",
      join_keys: [alias_id: :id, species_id: :id]

    many_to_many :taxonomies, Gallformers.Taxonomy.Taxonomy,
      join_through: "taxonomyalias",
      join_keys: [alias_id: :id, taxonomy_id: :id]
  end
end
