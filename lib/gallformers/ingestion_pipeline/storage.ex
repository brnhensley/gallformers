defmodule Gallformers.IngestionPipeline.Storage do
  @moduledoc """
  S3-backed artifact storage for ingestion pipeline outputs.
  """

  use Boundary,
    deps: [Gallformers.Storage],
    exports: :all

  alias Gallformers.Storage.SourceArtifacts

  @type stage :: atom() | String.t()

  @doc """
  Returns the S3 key for a pipeline artifact.
  """
  @spec artifact_path(integer(), stage(), String.t()) :: String.t()
  def artifact_path(ingestion_id, stage, filename)
      when is_integer(ingestion_id) and is_binary(filename) do
    SourceArtifacts.private_artifact_path(ingestion_id, stage, filename)
  end

  @doc """
  Uploads an artifact to S3 and returns its S3 key.
  """
  @spec upload_artifact(integer(), stage(), String.t(), binary(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
  def upload_artifact(ingestion_id, stage, filename, content, content_type)
      when is_binary(content) and is_binary(content_type) do
    SourceArtifacts.upload_private_artifact(ingestion_id, stage, filename, content, content_type)
  end

  @doc """
  Downloads an artifact from S3.
  """
  @spec download_artifact(integer(), stage(), String.t()) :: {:ok, binary()} | {:error, term()}
  def download_artifact(ingestion_id, stage, filename) do
    SourceArtifacts.download_private_artifact(ingestion_id, stage, filename)
  end

  @doc """
  Lists every artifact key stored for an ingestion under its canonical prefix.
  """
  @spec list_artifacts_for_ingestion(integer()) :: {:ok, [String.t()]} | {:error, term()}
  def list_artifacts_for_ingestion(ingestion_id) when is_integer(ingestion_id) do
    SourceArtifacts.list_private_artifacts_for_ingestion(ingestion_id)
  end

  @doc """
  Deletes every artifact stored for an ingestion under its canonical prefix.
  """
  @spec delete_artifacts_for_ingestion(integer()) :: :ok | {:error, term()}
  def delete_artifacts_for_ingestion(ingestion_id) when is_integer(ingestion_id) do
    SourceArtifacts.delete_private_artifacts_for_ingestion(ingestion_id)
  end
end
