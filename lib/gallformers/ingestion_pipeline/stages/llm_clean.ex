defmodule Gallformers.IngestionPipeline.Stages.LLMClean do
  @moduledoc """
  Uses the LLM client to clean preprocessed text into structured markdown.
  """

  @behaviour Gallformers.IngestionPipeline.StageWorker

  alias Gallformers.IngestionPipeline.Broadcaster
  alias Gallformers.IngestionPipeline.LLMClient
  alias Gallformers.IngestionPipeline.Storage
  alias Gallformers.Ingestions
  alias Gallformers.Ingestions.SourceIngestion

  @chunk_size 6000
  @max_tokens 8192
  @max_concurrency 4
  @task_timeout 130_000

  @impl true
  def stage_name, do: :llm_clean

  @impl true
  def perform_stage(%SourceIngestion{} = ingestion) do
    with {:ok, preprocessed_text} <-
           Storage.download_artifact(ingestion.id, :preprocess, "text.txt"),
         prompt <- load_prompt(),
         chunks <- LLMClient.chunk_text(preprocessed_text, @chunk_size),
         {:ok, cleaned_text} <- clean_chunks(prompt, chunks),
         {:ok, _artifact_path} <-
           Storage.upload_artifact(
             ingestion.id,
             :llm_clean,
             "text.txt",
             cleaned_text,
             "text/plain"
           ),
         {:ok, updated_ingestion} <-
           Ingestions.transition_source_ingestion_workflow(ingestion, :llm_clean_succeeded),
         :ok <- Broadcaster.broadcast_stage_complete(ingestion.id, :llm_clean) do
      {:ok, updated_ingestion}
    end
  end

  defp clean_chunks(_prompt, []), do: {:ok, ""}

  defp clean_chunks(prompt, chunks) do
    chunks
    |> Task.async_stream(
      &clean_chunk(prompt, &1),
      max_concurrency: @max_concurrency,
      ordered: true,
      timeout: @task_timeout
    )
    |> Enum.reduce_while({:ok, []}, &reduce_chunk_result/2)
    |> case do
      {:ok, cleaned_chunks} -> {:ok, cleaned_chunks |> Enum.reverse() |> Enum.join("\n\n")}
      error -> error
    end
  end

  defp clean_chunk(prompt, chunk) do
    case llm_client().completion(:llm_clean, prompt, chunk, max_tokens: @max_tokens) do
      {:ok, cleaned_chunk, _usage} -> {:ok, cleaned_chunk}
      {:error, reason} -> {:error, reason}
      {:error, reason, status} -> {:error, {reason, status}}
    end
  end

  defp reduce_chunk_result({:ok, {:ok, cleaned_chunk}}, {:ok, acc}),
    do: {:cont, {:ok, [cleaned_chunk | acc]}}

  defp reduce_chunk_result({:ok, {:error, reason}}, _acc), do: {:halt, {:error, reason}}
  defp reduce_chunk_result({:exit, reason}, _acc), do: {:halt, {:error, reason}}

  defp load_prompt do
    [:code.priv_dir(:gallformers), "prompts", "llm_clean.txt"]
    |> Path.join()
    |> File.read!()
  end

  defp llm_client do
    :gallformers
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:llm_client, LLMClient)
  end
end
