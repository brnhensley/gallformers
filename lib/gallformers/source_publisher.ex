defmodule Gallformers.SourcePublisher do
  @moduledoc """
  Bridges reviewed ingestions to published public source artifacts.
  """

  use Boundary,
    deps: [Gallformers.Ingestions, Gallformers.Sources, Gallformers.Storage],
    exports: :all

  alias Gallformers.Ingestions.SourceIngestion
  alias Gallformers.Sources.Source
  alias Gallformers.Storage.SourceArtifacts

  @assembled_markdown_suffix "assemble/output.md"

  @doc """
  Publishes the assembled markdown for a reviewed ingestion to the canonical
  public source markdown path.
  """
  @spec publish_markdown(Source.t(), SourceIngestion.t()) ::
          {:ok, %{bucket: String.t(), path: String.t(), url: String.t()}}
          | {:error, term()}
  def publish_markdown(%Source{} = source, %SourceIngestion{} = ingestion) do
    with {:ok, private_path} <- assembled_markdown_path(ingestion) do
      source
      |> SourceArtifacts.published_markdown_path()
      |> then(&SourceArtifacts.copy_private_to_public(private_path, &1))
      |> case do
        {:error, :private_artifact_not_found} -> {:error, :private_markdown_not_found}
        result -> result
      end
    end
  end

  defp assembled_markdown_path(%SourceIngestion{} = ingestion) do
    case SourceArtifacts.private_artifact_path(
           ingestion.artifacts_path,
           @assembled_markdown_suffix
         ) do
      path when is_binary(path) -> {:ok, path}
      nil -> {:error, :missing_artifacts_path}
    end
  end
end
