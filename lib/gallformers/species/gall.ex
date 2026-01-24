defmodule Gallformers.Species.Gall do
  @moduledoc """
  Ecto schema for the gall table.

  Galls are abnormal plant growths caused by insects, mites, or other organisms.
  This schema captures the gall-specific attributes separate from the species data.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @behaviour Gallformers.SchemaFields

  # No user-facing required fields - taxoncode is hardcoded internally
  @required_fields []

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

    belongs_to :taxontype, Gallformers.Species.TaxonType,
      foreign_key: :taxoncode,
      references: :taxoncode,
      define_field: false

    has_many :gall_species, Gallformers.Species.GallSpecies

    # Filter field associations
    many_to_many :colors, Gallformers.FilterFields.Color,
      join_through: "gallcolor",
      join_keys: [gall_id: :id, color_id: :id]

    many_to_many :shapes, Gallformers.FilterFields.Shape,
      join_through: "gallshape",
      join_keys: [gall_id: :id, shape_id: :id]

    many_to_many :textures, Gallformers.FilterFields.Texture,
      join_through: "galltexture",
      join_keys: [gall_id: :id, texture_id: :id]

    many_to_many :locations, Gallformers.FilterFields.Location,
      join_through: "galllocation",
      join_keys: [gall_id: :id, location_id: :id]

    many_to_many :alignments, Gallformers.FilterFields.Alignment,
      join_through: "gallalignment",
      join_keys: [gall_id: :id, alignment_id: :id]

    many_to_many :cells, Gallformers.FilterFields.Cells,
      join_through: "gallcells",
      join_keys: [gall_id: :id, cells_id: :id]

    many_to_many :walls, Gallformers.FilterFields.Walls,
      join_through: "gallwalls",
      join_keys: [gall_id: :id, walls_id: :id]

    many_to_many :forms, Gallformers.FilterFields.Form,
      join_through: "gallform",
      join_keys: [gall_id: :id, form_id: :id]

    many_to_many :seasons, Gallformers.FilterFields.Season,
      join_through: "gallseason",
      join_keys: [gall_id: :id, season_id: :id]
  end

  @impl Gallformers.SchemaFields
  def required_fields, do: @required_fields

  @impl Gallformers.SchemaFields
  def required_associations, do: [:hosts]

  @doc """
  Creates a changeset for a gall.

  The `taxoncode` is always set to "gall" internally.
  """
  def changeset(gall, attrs) do
    gall
    |> cast(attrs, [:detachable, :undescribed])
    |> put_change(:taxoncode, "gall")
  end
end
