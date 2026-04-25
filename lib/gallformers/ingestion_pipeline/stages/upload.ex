defmodule Gallformers.IngestionPipeline.Stages.Upload do
  @moduledoc """
  Finalizes a successful ingestion by compiling the artifact manifest and
  marking the ingestion ready for human review.
  """

  @behaviour Gallformers.IngestionPipeline.StageWorker

  alias Gallformers.IngestionPipeline.Broadcaster
  alias Gallformers.IngestionPipeline.Storage
  alias Gallformers.Ingestions
  alias Gallformers.Ingestions.SourceIngestion

  @impl true
  def stage_name, do: :upload

  @spec artifact_manifest(integer()) :: {:ok, [String.t()]} | {:error, term()}
  def artifact_manifest(ingestion_id) when is_integer(ingestion_id) do
    Storage.list_artifacts_for_ingestion(ingestion_id)
  end

  @impl true
  def perform_stage(%SourceIngestion{} = ingestion) do
    with {:ok, _manifest} <- artifact_manifest(ingestion.id),
         {:ok, updated_ingestion} <-
           Ingestions.transition_source_ingestion_workflow(ingestion, :upload_succeeded),
         :ok <- Broadcaster.broadcast_review_ready(ingestion.id) do
      {:ok, updated_ingestion}
    end
  end
end
