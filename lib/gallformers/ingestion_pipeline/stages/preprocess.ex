defmodule Gallformers.IngestionPipeline.Stages.Preprocess do
  @moduledoc """
  Deterministically preprocesses extracted text and persists duplicate signals.
  """

  @behaviour Gallformers.IngestionPipeline.StageWorker

  alias Gallformers.IngestionPipeline.DuplicateSignals
  alias Gallformers.IngestionPipeline.Storage
  alias Gallformers.IngestionPipeline.TextProcessing
  alias Gallformers.Ingestions
  alias Gallformers.Ingestions.SourceIngestion

  @impl true
  def stage_name, do: :preprocess

  @impl true
  def perform_stage(%SourceIngestion{} = ingestion) do
    with {:ok, extracted_text} <- Storage.download_artifact(ingestion.id, :extract, "text.txt"),
         cleaned_text <- TextProcessing.preprocess(extracted_text),
         sniffed <- TextProcessing.cheap_sniff(cleaned_text),
         sha256 <- TextProcessing.compute_sha256(cleaned_text),
         {:ok, _updated_signals} <-
           Ingestions.record_duplicate_signals(ingestion, signal_attrs(sniffed, sha256)),
         {:ok, _artifact_path} <-
           Storage.upload_artifact(
             ingestion.id,
             :preprocess,
             "text.txt",
             cleaned_text,
             "text/plain"
           ) do
      Ingestions.transition_source_ingestion_workflow(ingestion, :preprocess_succeeded)
    end
  end

  defp signal_attrs(sniffed, sha256) do
    DuplicateSignals.signal_attrs(
      %{
        doi: sniffed.doi,
        title: sniffed.title,
        authors: sniffed.authors,
        year: sniffed.year
      },
      %{preprocessed_text_sha256: sha256}
    )
  end
end
