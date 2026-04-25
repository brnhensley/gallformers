defmodule Gallformers.IngestionPipeline.Stages.DataExtract do
  @moduledoc """
  Extracts structured gall records from cleaned markdown via the LLM client.
  """

  @behaviour Gallformers.IngestionPipeline.StageWorker

  alias Gallformers.IngestionPipeline.Broadcaster
  alias Gallformers.IngestionPipeline.LLMClient
  alias Gallformers.IngestionPipeline.Schema
  alias Gallformers.IngestionPipeline.Storage
  alias Gallformers.Ingestions
  alias Gallformers.Ingestions.SourceIngestion

  @chunk_size 3000
  @max_tokens 6000
  @max_concurrency 4
  @task_timeout 300_000
  @json_attempts 3

  @impl true
  def stage_name, do: :data_extract

  @impl true
  def perform_stage(%SourceIngestion{} = ingestion) do
    with {:ok, cleaned_text} <- Storage.download_artifact(ingestion.id, :llm_clean, "text.txt"),
         prompt <- load_prompt(schema_module()),
         chunks <- LLMClient.chunk_text(cleaned_text, @chunk_size),
         {:ok, records} <- extract_chunks(prompt, chunks),
         {:ok, validated_records} <- schema_module().validate(records),
         {:ok, _artifact_path} <-
           Storage.upload_artifact(
             ingestion.id,
             :data_extract,
             "output.json",
             Jason.encode!(validated_records, pretty: true),
             "application/json"
           ),
         {:ok, updated_ingestion} <-
           Ingestions.transition_source_ingestion_workflow(ingestion, :data_extract_succeeded),
         :ok <- Broadcaster.broadcast_stage_complete(ingestion.id, :data_extract) do
      {:ok, updated_ingestion}
    end
  end

  defp extract_chunks(_prompt, []), do: {:ok, []}

  defp extract_chunks(prompt, chunks) do
    chunks
    |> Task.async_stream(
      &extract_chunk(prompt, &1),
      max_concurrency: @max_concurrency,
      ordered: true,
      timeout: @task_timeout
    )
    |> Enum.reduce_while({:ok, []}, &reduce_chunk_result/2)
    |> case do
      {:ok, chunk_records} ->
        {:ok, chunk_records |> Enum.reverse() |> List.flatten()}

      error ->
        error
    end
  end

  defp reduce_chunk_result({:ok, {:ok, records}}, {:ok, acc}),
    do: {:cont, {:ok, [records | acc]}}

  defp reduce_chunk_result({:ok, {:error, reason}}, _acc), do: {:halt, {:error, reason}}
  defp reduce_chunk_result({:exit, reason}, _acc), do: {:halt, {:error, reason}}

  defp extract_chunk(prompt, chunk, attempts_remaining \\ @json_attempts)

  defp extract_chunk(_prompt, _chunk, 0), do: {:error, :invalid_json}

  defp extract_chunk(prompt, chunk, attempts_remaining) do
    case llm_client().completion(:data_extract, prompt, chunk,
           max_tokens: @max_tokens,
           merge_prompt: true
         ) do
      {:ok, response, _usage} ->
        case parse_json_response(response) do
          {:ok, records} ->
            {:ok, records}

          {:error, :invalid_json} ->
            extract_chunk(prompt, chunk, attempts_remaining - 1)
        end

      {:error, reason} ->
        {:error, reason}

      {:error, reason, status} ->
        {:error, {reason, status}}
    end
  end

  defp parse_json_response(response) do
    response
    |> strip_fenced_json()
    |> trim_to_json_array()
    |> Jason.decode()
    |> case do
      {:ok, records} when is_list(records) -> {:ok, records}
      _ -> {:error, :invalid_json}
    end
  end

  defp strip_fenced_json(response) do
    case Regex.run(~r/```(?:json)?\s*\n(.*?)(?:\n?```|\z)/s, response, capture: :all_but_first) do
      [json] -> String.trim(json)
      _ -> String.trim(response)
    end
  end

  defp trim_to_json_array(response) do
    case :binary.match(response, "[") do
      :nomatch ->
        response

      {bracket_index, _length} ->
        String.slice(response, bracket_index, String.length(response) - bracket_index)
    end
  end

  defp load_prompt(schema_module) do
    [:code.priv_dir(:gallformers), "prompts", "data_extract.txt"]
    |> Path.join()
    |> File.read!()
    |> String.replace("{{SCHEMA}}", schema_module.prompt_text())
  end

  defp llm_client do
    :gallformers
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:llm_client, LLMClient)
  end

  defp schema_module do
    :gallformers
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:schema_module, Schema)
  end
end
