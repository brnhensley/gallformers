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
          datacomplete: boolean(),
          abundance_id: integer() | nil
        }

  schema "species" do
    field :name, :string
    field :taxoncode, :string
    field :datacomplete, :boolean, default: false

    belongs_to :abundance, Gallformers.Species.Abundance

    belongs_to :taxontype, Gallformers.Species.TaxonType,
      foreign_key: :taxoncode,
      references: :taxoncode,
      define_field: false

    has_many :images, Gallformers.Species.Image
    has_many :gall_species, Gallformers.Species.GallSpecies
    has_many :species_sources, Gallformers.Species.SpeciesSource

    # Host relationships - this species as a gall
    has_many :host_relations, Gallformers.Hosts.Host, foreign_key: :gall_species_id

    # Host relationships - this species as a host plant
    has_many :gall_relations, Gallformers.Hosts.Host, foreign_key: :host_species_id

    many_to_many :aliases, Gallformers.Species.Alias,
      join_through: "aliasspecies",
      join_keys: [species_id: :id, alias_id: :id]

    many_to_many :taxonomies, Gallformers.Taxonomy.Taxonomy,
      join_through: "speciestaxonomy",
      join_keys: [species_id: :id, taxonomy_id: :id]

    many_to_many :places, Gallformers.Places.Place,
      join_through: "speciesplace",
      join_keys: [species_id: :id, place_id: :id]
  end
end
