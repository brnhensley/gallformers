defmodule Gallformers.Species.GallSpecies do
  @moduledoc """
  Ecto schema for the gallspecies join table.

  Links species to galls (many-to-many relationship).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @behaviour Gallformers.SchemaFields

  @primary_key false

  @required_fields [:species_id, :gall_id]

  @type t :: %__MODULE__{
          species_id: integer(),
          gall_id: integer()
        }

  schema "gallspecies" do
    belongs_to :species, Gallformers.Species.Species, primary_key: true
    belongs_to :gall, Gallformers.Species.Gall, primary_key: true
  end

  @impl Gallformers.SchemaFields
  def required_fields, do: @required_fields

  @doc """
  Creates a changeset for a gall-species association.
  """
  def changeset(gall_species, attrs) do
    gall_species
    |> cast(attrs, [:species_id, :gall_id])
    |> validate_required(@required_fields)
    |> unique_constraint([:species_id, :gall_id], name: :gallspecies_species_id_gall_id)
    |> foreign_key_constraint(:species_id)
    |> foreign_key_constraint(:gall_id)
  end
end
