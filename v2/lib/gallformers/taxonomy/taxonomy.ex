defmodule Gallformers.Taxonomy.Taxonomy do
  @moduledoc """
  Ecto schema for the taxonomy table.

  Represents a taxonomic classification (family, genus, species, etc.)
  with a hierarchical parent-child relationship.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t() | nil,
          description: String.t() | nil,
          type: String.t() | nil,
          parent_id: integer() | nil
        }

  @taxonomy_types ~w(family genus section)

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

  @doc """
  Creates a changeset for a taxonomy.
  """
  def changeset(taxonomy, attrs) do
    taxonomy
    |> cast(attrs, [:name, :description, :type, :parent_id])
    |> validate_required([:name, :type])
    |> validate_inclusion(:type, @taxonomy_types)
    |> validate_length(:name, min: 1, max: 255)
    |> unique_constraint(:name, name: :taxonomy_name_type_unique)
  end

  @doc """
  Returns the list of valid taxonomy types.
  """
  def taxonomy_types, do: @taxonomy_types
end
