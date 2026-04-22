defmodule Gallformers.Repo.Migrations.AddSourceIngestions do
  use Ecto.Migration

  def up do
    create table(:source_ingestions) do
      add :input_type, :string, null: false
      add :status, :string, null: false, default: "processing"
      add :processing_stage, :string, null: false, default: "submitted"
      add :raw_input_sha256, :string
      add :preprocessed_text_sha256, :string
      add :doi, :string
      add :normalized_doi, :string
      add :title, :text
      add :authors, {:array, :text}, null: false, default: []
      add :normalized_title, :text
      add :title_fingerprint, :string
      add :author_fingerprint, :string
      add :publication_year, :integer
      add :minhash_signature, {:array, :integer}, null: false, default: []

      add :duplicate_of_source_ingestion_id,
          references(:source_ingestions, on_delete: :nilify_all)

      add :source_id, references(:source, on_delete: :nilify_all)
      add :artifacts_path, :text, null: false, default: ""
      add :uploaded_by_id, references(:users, on_delete: :nilify_all)
      add :error_stage, :string
      add :error_message, :text
      add :failed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:source_ingestions, [:status, :inserted_at])
    create index(:source_ingestions, [:processing_stage])
    create index(:source_ingestions, [:source_id], name: :idx_source_ingestions_source_id)

    create index(:source_ingestions, [:uploaded_by_id],
             name: :idx_source_ingestions_uploaded_by_id
           )

    create index(:source_ingestions, [:duplicate_of_source_ingestion_id],
             name: :idx_source_ingestions_duplicate_of_source_ingestion_id
           )

    execute """
    CREATE UNIQUE INDEX source_ingestions_artifacts_path_unique
    ON source_ingestions (artifacts_path)
    WHERE artifacts_path <> ''
    """

    execute """
    CREATE INDEX idx_source_ingestions_raw_input_sha256
    ON source_ingestions (raw_input_sha256)
    WHERE raw_input_sha256 IS NOT NULL
    """

    execute """
    CREATE INDEX idx_source_ingestions_preprocessed_text_sha256
    ON source_ingestions (preprocessed_text_sha256)
    WHERE preprocessed_text_sha256 IS NOT NULL
    """

    execute """
    CREATE INDEX idx_source_ingestions_normalized_doi
    ON source_ingestions (normalized_doi)
    WHERE normalized_doi IS NOT NULL
    """

    execute """
    CREATE INDEX idx_source_ingestions_normalized_title
    ON source_ingestions (normalized_title)
    WHERE normalized_title IS NOT NULL
    """

    execute """
    CREATE INDEX idx_source_ingestions_bibliographic_fingerprint
    ON source_ingestions (title_fingerprint, author_fingerprint, publication_year)
    WHERE title_fingerprint IS NOT NULL OR author_fingerprint IS NOT NULL
    """

    execute """
    ALTER TABLE source_ingestions
    ADD CONSTRAINT source_ingestions_input_type_check
    CHECK (input_type IN ('pdf', 'url', 'text', 'docx'))
    """

    execute """
    ALTER TABLE source_ingestions
    ADD CONSTRAINT source_ingestions_status_check
    CHECK (
      status IN (
        'processing',
        'needs_duplicate_review',
        'needs_review',
        'duplicate_confirmed',
        'complete',
        'failed'
      )
    )
    """

    execute """
    ALTER TABLE source_ingestions
    ADD CONSTRAINT source_ingestions_processing_stage_check
    CHECK (
      processing_stage IN (
        'submitted',
        'extract',
        'preprocess',
        'hash_and_dedup',
        'duplicate_review',
        'llm_clean',
        'metadata',
        'data_extract',
        'assemble',
        'upload',
        'review',
        'complete',
        'failed'
      )
    )
    """

    execute """
    ALTER TABLE source_ingestions
    ADD CONSTRAINT source_ingestions_no_self_duplicate
    CHECK (
      duplicate_of_source_ingestion_id IS NULL
      OR duplicate_of_source_ingestion_id <> id
    )
    """

    create table(:source_ingestion_duplicate_candidates) do
      add :source_ingestion_id, references(:source_ingestions, on_delete: :delete_all),
        null: false

      add :candidate_source_ingestion_id, references(:source_ingestions, on_delete: :delete_all),
        null: false

      add :status, :string, null: false, default: "pending"
      add :evidence, :map, null: false, default: %{}
      add :reviewed_by_id, references(:users, on_delete: :nilify_all)
      add :reviewed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(
             :source_ingestion_duplicate_candidates,
             [:source_ingestion_id, :candidate_source_ingestion_id],
             name: :source_ingestion_duplicate_candidates_unique_pair
           )

    create index(:source_ingestion_duplicate_candidates, [:source_ingestion_id, :status],
             name: :idx_source_ingestion_duplicate_candidates_status
           )

    create index(:source_ingestion_duplicate_candidates, [:candidate_source_ingestion_id],
             name: :idx_source_ingestion_duplicate_candidates_candidate_id
           )

    create index(:source_ingestion_duplicate_candidates, [:reviewed_by_id],
             name: :idx_source_ingestion_duplicate_candidates_reviewed_by_id
           )

    execute """
    ALTER TABLE source_ingestion_duplicate_candidates
    ADD CONSTRAINT source_ingestion_duplicate_candidates_status_check
    CHECK (status IN ('pending', 'confirmed', 'rejected', 'auto_confirmed'))
    """

    execute """
    ALTER TABLE source_ingestion_duplicate_candidates
    ADD CONSTRAINT source_ingestion_duplicate_candidates_no_self_match
    CHECK (source_ingestion_id <> candidate_source_ingestion_id)
    """

    create table(:source_ingestion_species) do
      add :source_ingestion_id, references(:source_ingestions, on_delete: :delete_all),
        null: false

      add :position, :integer, null: false
      add :extracted_name, :text
      add :extracted_authority, :text
      add :species_id, references(:species, on_delete: :nilify_all)
      add :status, :string, null: false, default: "pending"
      add :description_prose, :text, null: false, default: ""
      add :extraction_payload, :map, null: false, default: %{}
      add :review_payload, :map, null: false, default: %{}
      add :reviewed_by_id, references(:users, on_delete: :nilify_all)
      add :reviewed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:source_ingestion_species, [:source_ingestion_id, :position],
             name: :source_ingestion_species_unique_position
           )

    create index(:source_ingestion_species, [:source_ingestion_id, :status],
             name: :idx_source_ingestion_species_status
           )

    create index(:source_ingestion_species, [:species_id], name: :idx_source_ingestion_species_id)

    create index(:source_ingestion_species, [:reviewed_by_id],
             name: :idx_source_ingestion_species_reviewed_by_id
           )

    execute """
    ALTER TABLE source_ingestion_species
    ADD CONSTRAINT source_ingestion_species_status_check
    CHECK (status IN ('pending', 'mapped', 'created', 'skipped', 'complete'))
    """

    execute """
    ALTER TABLE source_ingestion_species
    ADD CONSTRAINT source_ingestion_species_position_check
    CHECK (position >= 0)
    """
  end

  def down do
    drop table(:source_ingestion_species)
    drop table(:source_ingestion_duplicate_candidates)
    drop table(:source_ingestions)
  end
end
