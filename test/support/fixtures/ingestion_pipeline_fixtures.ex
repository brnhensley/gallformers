defmodule Gallformers.IngestionPipelineFixtures do
  @moduledoc false

  alias Gallformers.Ingestions
  alias Gallformers.Ingestions.{DuplicateCandidate, SourceIngestion}

  @spec source_ingestion_fixture(map()) :: SourceIngestion.t()
  def source_ingestion_fixture(attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          input_type: "pdf",
          status: "processing",
          processing_stage: "submitted"
        },
        attrs
      )

    {:ok, ingestion} = Ingestions.create_source_ingestion(attrs)
    ingestion
  end

  @spec duplicate_candidate_fixture(SourceIngestion.t(), SourceIngestion.t(), map()) ::
          DuplicateCandidate.t()
  def duplicate_candidate_fixture(ingestion, candidate, attrs \\ %{}) do
    {:ok, duplicate_candidate} =
      Ingestions.create_duplicate_candidate(ingestion, candidate, attrs)

    duplicate_candidate
  end
end
