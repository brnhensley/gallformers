defmodule Gallformers.Taxonomy.Taxonomy do
  @moduledoc """
  Ecto schema for the taxonomy table.

  Represents a taxonomic classification (family, genus, species, etc.)
  with a hierarchical parent-child relationship.
  """
  use Ecto.Schema

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t() | nil,
          description: String.t() | nil,
          type: String.t() | nil,
          parent_id: integer() | nil
        }

  schema "taxonomy" do
    field :name, :string
    field :description, :string, default: ""
    field :type, :string

    belongs_to :parent, __MODULE__
    has_many :children, __MODULE__, foreign_key: :parent_id

    many_to_many :species, Gallformers.Species.Species,
      join_through: "speciestaxonomy",
      join_keys: [taxonomy_id: :id, species_id: :id]

    many_to_many :aliases, Gallformers.Species.Alias,
      join_through: "taxonomyalias",
      join_keys: [taxonomy_id: :id, alias_id: :id]
  end
end
