defmodule Gallformers.Ingestions.DuplicateCandidate do
  @moduledoc """
  Persisted duplicate-review record linking a submission to a candidate ingestion.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(pending confirmed rejected auto_confirmed)
  @required_fields [:source_ingestion_id, :candidate_source_ingestion_id, :status]
  @optional_fields [:evidence, :reviewed_by_id, :reviewed_at]

  @type status :: String.t()

  @type t :: %__MODULE__{
          id: integer() | nil,
          source_ingestion_id: integer() | nil,
          candidate_source_ingestion_id: integer() | nil,
          status: status(),
          evidence: map(),
          reviewed_by_id: integer() | nil,
          reviewed_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "source_ingestion_duplicate_candidates" do
    field :status, :string, default: "pending"
    field :evidence, :map, default: %{}
    field :reviewed_at, :utc_datetime

    belongs_to :source_ingestion, Gallformers.Ingestions.SourceIngestion
    belongs_to :candidate_source_ingestion, Gallformers.Ingestions.SourceIngestion
    belongs_to :reviewed_by, Gallformers.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @spec statuses() :: [status()]
  def statuses, do: @statuses

  @doc """
  Creates a changeset for a duplicate candidate.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(duplicate_candidate, attrs) do
    duplicate_candidate
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint([:source_ingestion_id, :candidate_source_ingestion_id],
      name: :source_ingestion_duplicate_candidates_unique_pair,
      message: "this duplicate candidate already exists"
    )
    |> foreign_key_constraint(:source_ingestion_id)
    |> foreign_key_constraint(:candidate_source_ingestion_id)
    |> foreign_key_constraint(:reviewed_by_id)
    |> check_constraint(:candidate_source_ingestion_id,
      name: :source_ingestion_duplicate_candidates_no_self_match,
      message: "cannot compare an ingestion against itself"
    )
  end
end
