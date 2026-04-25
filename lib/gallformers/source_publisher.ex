defmodule Gallformers.SourcePublisher do
  @moduledoc """
  Bridges reviewed ingestions to published public source artifacts.
  """

  use Boundary,
    deps: [Gallformers.Ingestions, Gallformers.Sources, Gallformers.Storage],
    exports: :all

  alias Gallformers.Ingestions
  alias Gallformers.Ingestions.SourceIngestion
  alias Gallformers.Sources.Publication, as: SourcePublication
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
      |> SourcePublication.published_markdown_path()
      |> then(&SourceArtifacts.copy_private_to_public(private_path, &1))
      |> normalize_publish_result()
    end
  end

  defp assembled_markdown_path(%SourceIngestion{} = ingestion) do
    case Ingestions.artifact_path(ingestion, @assembled_markdown_suffix) do
      path when is_binary(path) -> {:ok, path}
      nil -> {:error, :missing_artifacts_path}
    end
  end

  defp normalize_publish_result({:error, :private_artifact_not_found}) do
    {:error, :private_markdown_not_found}
  end

  defp normalize_publish_result(result), do: result
end
