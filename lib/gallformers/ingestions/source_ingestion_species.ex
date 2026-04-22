defmodule Gallformers.Ingestions.SourceIngestionSpecies do
  @moduledoc """
  Persisted gall-level review item derived from a source ingestion.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Gallformers.ChangesetHelpers, only: [trim_strings: 1]

  @statuses ~w(pending mapped created skipped complete)
  @required_fields [:source_ingestion_id, :position, :status]

  @optional_fields [
    :extracted_name,
    :extracted_authority,
    :species_id,
    :description_prose,
    :extraction_payload,
    :review_payload,
    :reviewed_by_id,
    :reviewed_at
  ]

  @type status :: String.t()

  @type t :: %__MODULE__{
          id: integer() | nil,
          source_ingestion_id: integer() | nil,
          position: integer(),
          extracted_name: String.t() | nil,
          extracted_authority: String.t() | nil,
          species_id: integer() | nil,
          status: status(),
          description_prose: String.t(),
          extraction_payload: map(),
          review_payload: map(),
          reviewed_by_id: integer() | nil,
          reviewed_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "source_ingestion_species" do
    field :position, :integer
    field :extracted_name, :string
    field :extracted_authority, :string
    field :status, :string, default: "pending"
    field :description_prose, :string, default: ""
    field :extraction_payload, :map, default: %{}
    field :review_payload, :map, default: %{}
    field :reviewed_at, :utc_datetime

    belongs_to :source_ingestion, Gallformers.Ingestions.SourceIngestion
    belongs_to :species, Gallformers.Species.Species
    belongs_to :reviewed_by, Gallformers.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @spec statuses() :: [status()]
  def statuses, do: @statuses

  @doc """
  Creates a changeset for a gall-level ingestion review item.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(source_ingestion_species, attrs) do
    source_ingestion_species
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> trim_strings()
    |> normalize_empty_strings([:extracted_name, :extracted_authority])
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> unique_constraint([:source_ingestion_id, :position],
      name: :source_ingestion_species_unique_position,
      message: "position has already been used for this ingestion"
    )
    |> foreign_key_constraint(:source_ingestion_id)
    |> foreign_key_constraint(:species_id)
    |> foreign_key_constraint(:reviewed_by_id)
  end

  defp normalize_empty_strings(changeset, fields) do
    Enum.reduce(fields, changeset, fn field, cs ->
      case get_change(cs, field) do
        "" -> put_change(cs, field, nil)
        _ -> cs
      end
    end)
  end
end
