defmodule Gallformers.IngestionPipeline.StageWorker do
  @moduledoc """
  Behaviour for durable ingestion pipeline stages executed by the orchestrator.

  The orchestrator runs as an Oban worker with `max_attempts: 3`, and each stage
  is expected to return either an updated `%SourceIngestion{}` or an error that
  can be recorded against the ingestion.
  """

  alias Gallformers.Ingestions.SourceIngestion

  @type reason :: term()

  @callback perform_stage(SourceIngestion.t()) :: {:ok, SourceIngestion.t()} | {:error, reason()}
  @callback stage_name() :: atom()
end
