defmodule Gallformers.IngestionPipeline.Workflow do
  @moduledoc """
  Canonical workflow semantics for persisted source-ingestion pipeline states.

  The pipeline persists a durable checkpoint via `status` and
  `processing_stage`. The checkpoint indicates what has already been completed,
  what is paused, or what terminal state has been reached. It does not
  necessarily mean "the stage currently running right now".
  """

  use Boundary,
    deps: [],
    exports: :all

  alias Gallformers.Ingestions.SourceIngestion

  @type stage ::
          :extract
          | :preprocess
          | :hash_and_dedup
          | :llm_clean
          | :metadata
          | :data_extract
          | :assemble
          | :upload

  @type state :: {String.t(), String.t()}

  @type ingestion_input :: SourceIngestion.t() | state()

  @type event ::
          :extract_succeeded
          | :preprocess_succeeded
          | :hash_and_dedup_succeeded
          | :duplicate_review_requested
          | :duplicate_rejected_resume
          | :duplicate_confirmed
          | :llm_clean_succeeded
          | :metadata_succeeded
          | :data_extract_succeeded
          | :assemble_succeeded
          | :upload_succeeded
          | :review_completed
          | {:stage_failed, stage(), term()}

  @reachable_states [
    {"processing", "submitted"},
    {"processing", "extract"},
    {"processing", "preprocess"},
    {"processing", "hash_and_dedup"},
    {"needs_duplicate_review", "duplicate_review"},
    {"processing", "duplicate_review"},
    {"duplicate_confirmed", "duplicate_review"},
    {"processing", "llm_clean"},
    {"processing", "metadata"},
    {"processing", "data_extract"},
    {"processing", "assemble"},
    {"needs_review", "review"},
    {"complete", "complete"},
    {"failed", "failed"}
  ]

  @next_stages %{
    {"processing", "submitted"} => :extract,
    {"processing", "extract"} => :preprocess,
    {"processing", "preprocess"} => :hash_and_dedup,
    {"processing", "hash_and_dedup"} => :llm_clean,
    {"processing", "duplicate_review"} => :llm_clean,
    {"processing", "llm_clean"} => :metadata,
    {"processing", "metadata"} => :data_extract,
    {"processing", "data_extract"} => :assemble,
    {"processing", "assemble"} => :upload
  }

  @transition_table %{
    {{"processing", "submitted"}, :extract_succeeded} => %{
      status: "processing",
      processing_stage: "extract"
    },
    {{"processing", "extract"}, :preprocess_succeeded} => %{
      status: "processing",
      processing_stage: "preprocess"
    },
    {{"processing", "preprocess"}, :hash_and_dedup_succeeded} => %{
      status: "processing",
      processing_stage: "hash_and_dedup"
    },
    {{"processing", "preprocess"}, :duplicate_review_requested} => %{
      status: "needs_duplicate_review",
      processing_stage: "duplicate_review"
    },
    {{"processing", "preprocess"}, :duplicate_confirmed} => %{
      status: "duplicate_confirmed",
      processing_stage: "duplicate_review"
    },
    {{"needs_duplicate_review", "duplicate_review"}, :duplicate_rejected_resume} => %{
      status: "processing",
      processing_stage: "duplicate_review"
    },
    {{"needs_duplicate_review", "duplicate_review"}, :duplicate_confirmed} => %{
      status: "duplicate_confirmed",
      processing_stage: "duplicate_review"
    },
    {{"processing", "hash_and_dedup"}, :llm_clean_succeeded} => %{
      status: "processing",
      processing_stage: "llm_clean"
    },
    {{"processing", "duplicate_review"}, :llm_clean_succeeded} => %{
      status: "processing",
      processing_stage: "llm_clean"
    },
    {{"processing", "llm_clean"}, :metadata_succeeded} => %{
      status: "processing",
      processing_stage: "metadata"
    },
    {{"processing", "metadata"}, :data_extract_succeeded} => %{
      status: "processing",
      processing_stage: "data_extract"
    },
    {{"processing", "data_extract"}, :assemble_succeeded} => %{
      status: "processing",
      processing_stage: "assemble"
    },
    {{"processing", "assemble"}, :upload_succeeded} => %{
      status: "needs_review",
      processing_stage: "review"
    },
    {{"needs_review", "review"}, :review_completed} => %{
      status: "complete",
      processing_stage: "complete"
    }
  }

  @duplicate_detection_excluded_statuses ["duplicate_confirmed", "failed"]

  @doc """
  Returns the persisted workflow state tuple.
  """
  @spec state(SourceIngestion.t()) ::
          state()
  def state(%{status: status, processing_stage: processing_stage}) do
    {status, processing_stage}
  end

  @doc """
  Returns the reachable persisted states for the workflow.
  """
  @spec reachable_states() :: [state()]
  def reachable_states, do: @reachable_states

  @doc """
  Returns whether a persisted status/stage pair is valid under the workflow.
  """
  @spec valid_state?(ingestion_input()) :: boolean()
  def valid_state?({status, processing_stage}) do
    {status, processing_stage} in @reachable_states
  end

  def valid_state?(%{} = ingestion), do: ingestion |> state() |> valid_state?()

  @doc """
  Returns whether the ingestion is paused awaiting external action.
  """
  @spec paused?(ingestion_input()) :: boolean()
  def paused?({"needs_duplicate_review", "duplicate_review"}), do: true
  def paused?({_, _}), do: false
  def paused?(%{} = ingestion), do: ingestion |> state() |> paused?()

  @doc """
  Returns statuses that should be excluded from duplicate-detection candidate queries.
  """
  @spec duplicate_detection_excluded_statuses() :: [String.t()]
  def duplicate_detection_excluded_statuses, do: @duplicate_detection_excluded_statuses

  @doc """
  Returns whether the ingestion is in a terminal persisted state.
  """
  @spec terminal?(ingestion_input()) :: boolean()
  def terminal?({"duplicate_confirmed", "duplicate_review"}), do: true
  def terminal?({"needs_review", "review"}), do: true
  def terminal?({"complete", "complete"}), do: true
  def terminal?({"failed", "failed"}), do: true
  def terminal?({_, _}), do: false
  def terminal?(%{} = ingestion), do: ingestion |> state() |> terminal?()

  @doc """
  Returns whether the ingestion can continue automated processing immediately.
  """
  @spec resumable?(ingestion_input()) :: boolean()
  def resumable?(ingestion) do
    case next_stage(ingestion) do
      {:run, _stage} -> true
      _ -> false
    end
  end

  @doc """
  Resolves the next runnable stage from the persisted checkpoint.

  Returns `:paused` for human-intervention states, `:terminal` for terminal
  states, and `{:error, :invalid_state}` for unsupported combinations.
  """
  @spec next_stage(ingestion_input()) ::
          {:run, stage()} | :paused | :terminal | {:error, :invalid_state}
  def next_stage(ingestion) do
    case normalized_state(ingestion) do
      {:ok, current_state} ->
        cond do
          paused?(current_state) ->
            :paused

          terminal?(current_state) ->
            :terminal

          Map.has_key?(@next_stages, current_state) ->
            {:run, Map.fetch!(@next_stages, current_state)}

          true ->
            {:error, :invalid_state}
        end

      {:error, :invalid_state} ->
        {:error, :invalid_state}
    end
  end

  @doc """
  Returns the persisted attrs for a workflow event.

  This is intentionally limited to workflow-owned attrs. Callers can merge any
  stage-specific or review-specific attrs around this result as needed.
  """
  @spec transition_attrs(ingestion_input(), event()) ::
          {:ok, map()} | {:error, :invalid_state | :invalid_transition}
  def transition_attrs(ingestion, {:stage_failed, stage, reason}) when is_atom(stage) do
    case normalized_state(ingestion) do
      {:ok, current_state} ->
        case next_stage(current_state) do
          {:run, ^stage} ->
            {:ok,
             %{
               status: "failed",
               processing_stage: "failed",
               error_stage: Atom.to_string(stage),
               error_message: format_error_message(reason)
             }}

          {:run, _other_stage} ->
            {:error, :invalid_transition}

          _ ->
            {:error, :invalid_transition}
        end

      {:error, :invalid_state} ->
        {:error, :invalid_state}
    end
  end

  def transition_attrs(ingestion, event) do
    case normalized_state(ingestion) do
      {:ok, current_state} ->
        case Map.fetch(@transition_table, {current_state, event}) do
          {:ok, attrs} -> {:ok, attrs}
          :error -> {:error, :invalid_transition}
        end

      {:error, :invalid_state} ->
        {:error, :invalid_state}
    end
  end

  defp normalized_state({_status, _processing_stage} = current_state) do
    if valid_state?(current_state) do
      {:ok, current_state}
    else
      {:error, :invalid_state}
    end
  end

  defp normalized_state(%{} = ingestion) do
    ingestion
    |> state()
    |> normalized_state()
  end

  defp format_error_message(reason) when is_binary(reason), do: reason
  defp format_error_message(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp format_error_message(reason), do: inspect(reason)
end
