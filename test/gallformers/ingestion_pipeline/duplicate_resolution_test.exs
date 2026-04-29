defmodule Gallformers.IngestionPipeline.DuplicateResolutionTest do
  use Gallformers.DataCase, async: false
  use Oban.Testing, repo: Gallformers.Repo

  alias Gallformers.Accounts
  alias Gallformers.IngestionPipeline.DuplicateResolution
  alias Gallformers.IngestionPipeline.Worker
  alias Gallformers.Ingestions

  test "confirm_duplicate/2 confirms the candidate and re-enqueues the orchestrator" do
    reviewer = user_fixture()
    canonical = source_ingestion_fixture(%{input_type: "url"})

    subject =
      source_ingestion_fixture(%{
        input_type: "pdf",
        status: "needs_duplicate_review",
        processing_stage: "duplicate_review"
      })

    {:ok, candidate} = Ingestions.create_duplicate_candidate(subject, canonical)

    Oban.Testing.with_testing_mode(:manual, fn ->
      assert {:ok, updated_ingestion} =
               DuplicateResolution.confirm_duplicate(candidate.id, reviewer.id)

      assert updated_ingestion.status == "duplicate_confirmed"
      assert updated_ingestion.processing_stage == "duplicate_review"
      assert updated_ingestion.duplicate_of_source_ingestion_id == canonical.id

      assert_enqueued(worker: Worker, queue: "extraction", args: %{ingestion_id: subject.id})
    end)
  end

  test "reject_duplicate/2 re-enqueues when the last pending candidate is rejected" do
    reviewer = user_fixture()

    subject =
      source_ingestion_fixture(%{
        input_type: "pdf",
        status: "needs_duplicate_review",
        processing_stage: "duplicate_review"
      })

    candidate_source = source_ingestion_fixture(%{input_type: "url"})
    {:ok, candidate} = Ingestions.create_duplicate_candidate(subject, candidate_source)

    Oban.Testing.with_testing_mode(:manual, fn ->
      assert {:ok, updated_ingestion} =
               DuplicateResolution.reject_duplicate(candidate.id, reviewer.id)

      assert updated_ingestion.status == "processing"
      assert updated_ingestion.processing_stage == "duplicate_review"

      assert_enqueued(worker: Worker, queue: "extraction", args: %{ingestion_id: subject.id})
    end)
  end

  test "reject_duplicate/2 does not re-enqueue when other pending candidates remain" do
    reviewer = user_fixture()

    subject =
      source_ingestion_fixture(%{
        input_type: "pdf",
        status: "needs_duplicate_review",
        processing_stage: "duplicate_review"
      })

    {:ok, first_candidate} =
      Ingestions.create_duplicate_candidate(
        subject,
        source_ingestion_fixture(%{input_type: "url"})
      )

    {:ok, _second_candidate} =
      Ingestions.create_duplicate_candidate(
        subject,
        source_ingestion_fixture(%{input_type: "text"})
      )

    Oban.Testing.with_testing_mode(:manual, fn ->
      assert {:ok, updated_ingestion} =
               DuplicateResolution.reject_duplicate(first_candidate.id, reviewer.id)

      assert updated_ingestion.status == "needs_duplicate_review"
      assert updated_ingestion.processing_stage == "duplicate_review"

      refute_enqueued(worker: Worker, queue: "extraction", args: %{ingestion_id: subject.id})
    end)
  end

  test "promote_to_unique/2 rejects all pending candidates and re-enqueues the orchestrator" do
    reviewer = user_fixture()

    subject =
      source_ingestion_fixture(%{
        input_type: "pdf",
        status: "needs_duplicate_review",
        processing_stage: "duplicate_review"
      })

    {:ok, first_candidate} =
      Ingestions.create_duplicate_candidate(
        subject,
        source_ingestion_fixture(%{input_type: "url"})
      )

    {:ok, second_candidate} =
      Ingestions.create_duplicate_candidate(
        subject,
        source_ingestion_fixture(%{input_type: "text"})
      )

    Oban.Testing.with_testing_mode(:manual, fn ->
      assert {:ok, updated_ingestion} =
               DuplicateResolution.promote_to_unique(subject.id, reviewer.id)

      assert updated_ingestion.status == "processing"
      assert updated_ingestion.processing_stage == "duplicate_review"

      assert Enum.map(Ingestions.list_duplicate_candidates(subject), & &1.status) == [
               "rejected",
               "rejected"
             ]

      assert_enqueued(worker: Worker, queue: "extraction", args: %{ingestion_id: subject.id})
    end)

    assert first_candidate.id != second_candidate.id
  end

  defp source_ingestion_fixture(attrs) do
    attrs =
      Map.merge(
        %{
          input_type: "pdf",
          status: "processing",
          processing_stage: "submitted"
        },
        attrs
      )

    {:ok, ingestion} = Ingestions.create_source_ingestion(attrs)
    ingestion
  end

  defp user_fixture do
    {:ok, user} =
      Accounts.create_user(%{
        auth0_id: "auth0|duplicate-resolution-#{System.unique_integer([:positive])}",
        display_name: "Duplicate Reviewer"
      })

    user
  end
end
