defmodule Gallformers.IngestionPipeline.Stages.Metadata do
  @moduledoc """
  Extracts bibliographic metadata from cleaned markdown via the LLM client.
  """

  @behaviour Gallformers.IngestionPipeline.StageWorker

  alias Gallformers.IngestionPipeline.Broadcaster
  alias Gallformers.IngestionPipeline.DuplicateSignals
  alias Gallformers.IngestionPipeline.Stages.LLMSupport
  alias Gallformers.IngestionPipeline.Storage
  alias Gallformers.Ingestions
  alias Gallformers.Ingestions.SourceIngestion

  @max_input_chars 24_000
  @max_tokens 1024
  @json_attempts 3

  @impl true
  def stage_name, do: :metadata

  @impl true
  def perform_stage(%SourceIngestion{} = ingestion) do
    with {:ok, cleaned_text} <- Storage.download_artifact(ingestion.id, :llm_clean, "text.txt"),
         prompt <- LLMSupport.load_prompt!("metadata.txt"),
         truncated_text <- String.slice(cleaned_text, 0, @max_input_chars),
         {:ok, raw_response, metadata_attrs} <-
           extract_metadata(prompt, truncated_text),
         {:ok, _updated_signals} <- Ingestions.record_duplicate_signals(ingestion, metadata_attrs),
         {:ok, _artifact_path} <-
           Storage.upload_artifact(
             ingestion.id,
             :metadata,
             "output.json",
             raw_response,
             "application/json"
           ),
         {:ok, updated_ingestion} <-
           Ingestions.transition_source_ingestion_workflow(ingestion, :metadata_succeeded),
         :ok <- Broadcaster.broadcast_stage_complete(ingestion.id, :metadata) do
      {:ok, updated_ingestion}
    end
  end

  defp extract_metadata(prompt, text, attempts_remaining \\ @json_attempts)

  defp extract_metadata(_prompt, _text, 0), do: {:error, :invalid_json}

  defp extract_metadata(prompt, text, attempts_remaining) do
    case llm_client().completion(:metadata, prompt, text, max_tokens: @max_tokens) do
      {:ok, raw_response, _usage} ->
        case parse_metadata(raw_response) do
          {:ok, metadata} ->
            {:ok, raw_response, DuplicateSignals.signal_attrs(metadata)}

          {:error, :invalid_json} ->
            extract_metadata(prompt, text, attempts_remaining - 1)
        end

      {:error, reason} ->
        {:error, reason}

      {:error, reason, status} ->
        {:error, {reason, status}}
    end
  end

  defp parse_metadata(raw_response) do
    raw_response
    |> LLMSupport.strip_fenced_json()
    |> Jason.decode()
    |> case do
      {:ok, decoded} -> cast_metadata(decoded)
      {:error, _reason} -> {:error, :invalid_json}
    end
  end

  defp cast_metadata(%{} = decoded) do
    with {:ok, title} <- cast_optional_string(Map.get(decoded, "title")),
         {:ok, authors} <- cast_authors(Map.get(decoded, "authors", [])),
         {:ok, year} <- cast_optional_integer(Map.get(decoded, "year")),
         {:ok, doi} <- cast_optional_string(Map.get(decoded, "doi")) do
      {:ok, %{title: title, authors: authors, year: year, doi: doi}}
    end
  end

  defp cast_metadata(_decoded), do: {:error, :invalid_json}

  defp cast_optional_string(nil), do: {:ok, nil}
  defp cast_optional_string(value) when is_binary(value), do: {:ok, value}
  defp cast_optional_string(_value), do: {:error, :invalid_json}

  defp cast_authors(authors) when is_list(authors) do
    if Enum.all?(authors, &is_binary/1) do
      {:ok, Enum.map(authors, &String.trim/1)}
    else
      {:error, :invalid_json}
    end
  end

  defp cast_authors(_authors), do: {:error, :invalid_json}

  defp cast_optional_integer(nil), do: {:ok, nil}
  defp cast_optional_integer(value) when is_integer(value), do: {:ok, value}
  defp cast_optional_integer(_value), do: {:error, :invalid_json}

  defp llm_client do
    LLMSupport.llm_client(__MODULE__)
  end
end
