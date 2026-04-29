defmodule Gallformers.IngestionPipeline.WorkflowTest do
  use ExUnit.Case, async: true

  alias Gallformers.IngestionPipeline.Workflow
  alias Gallformers.Ingestions.SourceIngestion

  test "every declared reachable state is valid" do
    Enum.each(Workflow.reachable_states(), fn {status, processing_stage} ->
      assert Workflow.valid_state?({status, processing_stage}) == true
      assert Workflow.valid_state?(ingestion(status, processing_stage)) == true
    end)
  end

  test "rejects invalid status and processing stage combinations" do
    refute Workflow.valid_state?({"needs_review", "llm_clean"})
    refute Workflow.valid_state?({"processing", "review"})
    refute Workflow.valid_state?({"duplicate_confirmed", "review"})
    refute Workflow.valid_state?({"processing", "upload"})
  end

  test "next_stage returns the correct runnable stage for every resumable state" do
    expected = %{
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

    Enum.each(expected, fn {{status, processing_stage}, stage} ->
      assert Workflow.next_stage({status, processing_stage}) == {:run, stage}
      assert Workflow.resumable?(ingestion(status, processing_stage)) == true
    end)
  end

  test "duplicate review states distinguish paused, resumable, and terminal outcomes" do
    assert Workflow.paused?({"needs_duplicate_review", "duplicate_review"}) == true
    assert Workflow.next_stage({"needs_duplicate_review", "duplicate_review"}) == :paused
    refute Workflow.resumable?({"needs_duplicate_review", "duplicate_review"})
    refute Workflow.terminal?({"needs_duplicate_review", "duplicate_review"})

    assert Workflow.resumable?({"processing", "duplicate_review"}) == true
    assert Workflow.next_stage({"processing", "duplicate_review"}) == {:run, :llm_clean}
    refute Workflow.paused?({"processing", "duplicate_review"})
    refute Workflow.terminal?({"processing", "duplicate_review"})

    assert Workflow.terminal?({"duplicate_confirmed", "duplicate_review"}) == true
    assert Workflow.next_stage({"duplicate_confirmed", "duplicate_review"}) == :terminal
    refute Workflow.paused?({"duplicate_confirmed", "duplicate_review"})
    refute Workflow.resumable?({"duplicate_confirmed", "duplicate_review"})
  end

  test "review, complete, and failed states are terminal" do
    assert Workflow.next_stage({"needs_review", "review"}) == :terminal
    assert Workflow.next_stage({"complete", "complete"}) == :terminal
    assert Workflow.next_stage({"failed", "failed"}) == :terminal
  end

  test "duplicate detection exclusion statuses are workflow-owned" do
    assert Workflow.duplicate_detection_excluded_statuses() == [
             "duplicate_confirmed",
             "failed"
           ]
  end

  test "transition_attrs resolves normal success checkpoints" do
    assert Workflow.transition_attrs({"processing", "submitted"}, :extract_succeeded) ==
             {:ok, %{status: "processing", processing_stage: "extract"}}

    assert Workflow.transition_attrs({"processing", "extract"}, :preprocess_succeeded) ==
             {:ok, %{status: "processing", processing_stage: "preprocess"}}

    assert Workflow.transition_attrs({"processing", "preprocess"}, :hash_and_dedup_succeeded) ==
             {:ok, %{status: "processing", processing_stage: "hash_and_dedup"}}

    assert Workflow.transition_attrs({"processing", "hash_and_dedup"}, :llm_clean_succeeded) ==
             {:ok, %{status: "processing", processing_stage: "llm_clean"}}

    assert Workflow.transition_attrs({"processing", "duplicate_review"}, :llm_clean_succeeded) ==
             {:ok, %{status: "processing", processing_stage: "llm_clean"}}

    assert Workflow.transition_attrs({"processing", "llm_clean"}, :metadata_succeeded) ==
             {:ok, %{status: "processing", processing_stage: "metadata"}}

    assert Workflow.transition_attrs({"processing", "metadata"}, :data_extract_succeeded) ==
             {:ok, %{status: "processing", processing_stage: "data_extract"}}

    assert Workflow.transition_attrs({"processing", "data_extract"}, :assemble_succeeded) ==
             {:ok, %{status: "processing", processing_stage: "assemble"}}

    assert Workflow.transition_attrs({"processing", "assemble"}, :upload_succeeded) ==
             {:ok, %{status: "needs_review", processing_stage: "review"}}

    assert Workflow.transition_attrs({"needs_review", "review"}, :review_completed) ==
             {:ok, %{status: "complete", processing_stage: "complete"}}
  end

  test "transition_attrs resolves duplicate pause, resume, and terminal duplicate transitions" do
    assert Workflow.transition_attrs({"processing", "preprocess"}, :duplicate_review_requested) ==
             {:ok, %{status: "needs_duplicate_review", processing_stage: "duplicate_review"}}

    assert Workflow.transition_attrs({"processing", "preprocess"}, :duplicate_confirmed) ==
             {:ok, %{status: "duplicate_confirmed", processing_stage: "duplicate_review"}}

    assert Workflow.transition_attrs(
             {"needs_duplicate_review", "duplicate_review"},
             :duplicate_rejected_resume
           ) ==
             {:ok, %{status: "processing", processing_stage: "duplicate_review"}}

    assert Workflow.transition_attrs(
             {"needs_duplicate_review", "duplicate_review"},
             :duplicate_confirmed
           ) ==
             {:ok, %{status: "duplicate_confirmed", processing_stage: "duplicate_review"}}
  end

  test "transition_attrs resolves stage failures only from the currently runnable stage" do
    assert Workflow.transition_attrs(
             {"processing", "submitted"},
             {:stage_failed, :extract, :boom}
           ) ==
             {:ok,
              %{
                status: "failed",
                processing_stage: "failed",
                error_stage: "extract",
                error_message: "boom"
              }}

    assert Workflow.transition_attrs(
             {"processing", "extract"},
             {:stage_failed, :preprocess, "bad"}
           ) ==
             {:ok,
              %{
                status: "failed",
                processing_stage: "failed",
                error_stage: "preprocess",
                error_message: "bad"
              }}

    assert Workflow.transition_attrs(
             {"needs_duplicate_review", "duplicate_review"},
             {:stage_failed, :llm_clean, :boom}
           ) == {:error, :invalid_transition}

    assert Workflow.transition_attrs(
             {"processing", "submitted"},
             {:stage_failed, :metadata, :boom}
           ) == {:error, :invalid_transition}
  end

  test "invalid states and unsupported transitions fail fast" do
    assert Workflow.next_stage({"processing", "upload"}) == {:error, :invalid_state}

    assert Workflow.transition_attrs({"processing", "upload"}, :upload_succeeded) ==
             {:error, :invalid_state}

    assert Workflow.transition_attrs({"processing", "submitted"}, :upload_succeeded) ==
             {:error, :invalid_transition}
  end

  defp ingestion(status, processing_stage) do
    %SourceIngestion{status: status, processing_stage: processing_stage}
  end
end
