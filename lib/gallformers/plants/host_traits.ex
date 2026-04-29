defmodule Gallformers.Plants.HostTraits do
  @moduledoc """
  Ecto schema for the host_traits table (1:1 extension of species).

  Stores host-specific attributes for species with taxoncode='plant'.
  Uses Class Table Inheritance pattern: species_id is both PK and FK.
  """
  use Ecto.Schema
  import Ecto.Changeset
  import Gallformers.ChangesetHelpers, only: [trim_strings: 1]

  @behaviour Gallformers.SchemaFields

  @required_fields [:species_id]
  @optional_fields [:wcvp_id, :powo_id, :wcvp_match_status, :range_confirmed, :wcvp_synced_at]
  @wcvp_match_statuses ~w(no_match ignored)

  @type t :: %__MODULE__{
          species_id: integer(),
          wcvp_id: String.t() | nil,
          powo_id: String.t() | nil,
          wcvp_match_status: String.t() | nil,
          range_confirmed: boolean(),
          wcvp_synced_at: DateTime.t() | nil
        }

  @primary_key {:species_id, :integer, autogenerate: false}
  @derive {Phoenix.Param, key: :species_id}

  schema "host_traits" do
    field :wcvp_id, :string
    field :powo_id, :string
    field :wcvp_match_status, :string
    field :range_confirmed, :boolean, default: false
    field :wcvp_synced_at, :utc_datetime

    belongs_to :species, Gallformers.Species.Species,
      foreign_key: :species_id,
      references: :id,
      define_field: false
  end

  @impl Gallformers.SchemaFields
  def required_fields, do: @required_fields

  @impl Gallformers.SchemaFields
  def required_associations, do: []

  def wcvp_match_statuses, do: @wcvp_match_statuses

  def changeset(host_traits, attrs) do
    host_traits
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> trim_strings()
    |> validate_required(@required_fields)
    |> validate_inclusion(:wcvp_match_status, @wcvp_match_statuses, allow_nil: true)
    |> foreign_key_constraint(:species_id)
  end
end
