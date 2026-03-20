defmodule Gallformers.Species.Abundance do
  @moduledoc """
  Ecto schema for the abundance table.

  Describes how common a species is (e.g., "common", "rare", "uncommon").
  """
  use Ecto.Schema
  import Ecto.Changeset
  import Gallformers.ChangesetHelpers, only: [trim_strings: 1]

  @behaviour Gallformers.SchemaFields

  @required_fields [:abundance]

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

  @impl Gallformers.SchemaFields
  def required_fields, do: @required_fields

  @doc """
  Creates a changeset for an abundance level.
  """
  def changeset(abundance, attrs) do
    abundance
    |> cast(attrs, [:abundance, :description, :reference])
    |> trim_strings()
    |> validate_required(@required_fields)
    |> unique_constraint(:abundance)
  end
end
