defmodule Gallformers.IngestionsTest do
  use Gallformers.DataCase, async: true

  alias Gallformers.Accounts
  alias Gallformers.Ingestions
  alias Gallformers.Sources
  alias Gallformers.Species.Species

  describe "create_source_ingestion/1" do
    test "creates a submission with a canonical per-ingestion artifacts path" do
      user = user_fixture()

      assert {:ok, ingestion} =
               Ingestions.create_source_ingestion(%{
                 input_type: "pdf",
                 uploaded_by_id: user.id,
                 title: "A New Gall Paper",
                 authors: ["A. Author", "B. Author"]
               })

      assert ingestion.status == "processing"
      assert ingestion.processing_stage == "submitted"
      assert ingestion.uploaded_by_id == user.id
      assert ingestion.artifacts_path == "source-ingestions/#{ingestion.id}"

      assert Ingestions.artifact_path(ingestion, "preprocessed.txt") ==
               "#{ingestion.artifacts_path}/preprocessed.txt"
    end

    test "rejects invalid input types" do
      assert {:error, changeset} = Ingestions.create_source_ingestion(%{input_type: "epub"})

      assert %{input_type: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "confirm_duplicate_candidate/2" do
    test "links a duplicate submission to the canonical ingestion root" do
      reviewer = user_fixture()
      canonical = source_ingestion_fixture(%{input_type: "pdf"})

      existing_duplicate =
        source_ingestion_fixture(%{
          input_type: "url",
          status: "duplicate_confirmed",
          processing_stage: "duplicate_review",
          duplicate_of_source_ingestion_id: canonical.id
        })

      subject =
        source_ingestion_fixture(%{
          input_type: "text",
          status: "needs_duplicate_review",
          processing_stage: "duplicate_review"
        })

      assert {:ok, candidate} =
               Ingestions.create_duplicate_candidate(subject, existing_duplicate, %{
                 evidence: %{"signal" => "normalized_doi"}
               })

      assert {:ok, %{candidate: updated_candidate, source_ingestion: updated_source_ingestion}} =
               Ingestions.confirm_duplicate_candidate(candidate, %{reviewed_by_id: reviewer.id})

      assert updated_candidate.status == "confirmed"
      assert updated_candidate.reviewed_by_id == reviewer.id
      refute is_nil(updated_candidate.reviewed_at)
      assert updated_source_ingestion.status == "duplicate_confirmed"
      assert updated_source_ingestion.processing_stage == "duplicate_review"
      assert updated_source_ingestion.duplicate_of_source_ingestion_id == canonical.id
    end

    test "refuses to confirm a second candidate after duplicate review is already resolved" do
      reviewer = user_fixture()

      subject =
        source_ingestion_fixture(%{
          input_type: "pdf",
          status: "needs_duplicate_review",
          processing_stage: "duplicate_review"
        })

      first_candidate_source = source_ingestion_fixture(%{input_type: "url"})
      second_candidate_source = source_ingestion_fixture(%{input_type: "text"})

      assert {:ok, first_candidate} =
               Ingestions.create_duplicate_candidate(subject, first_candidate_source)

      assert {:ok, second_candidate} =
               Ingestions.create_duplicate_candidate(subject, second_candidate_source)

      assert {:ok, _result} =
               Ingestions.confirm_duplicate_candidate(first_candidate, %{
                 reviewed_by_id: reviewer.id
               })

      assert {:error, changeset} =
               Ingestions.confirm_duplicate_candidate(second_candidate, %{
                 reviewed_by_id: reviewer.id
               })

      assert %{status: ["duplicate review is no longer pending"]} = errors_on(changeset)
    end
  end

  describe "reject_duplicate_candidate/2" do
    test "unlocks normal review when the last duplicate candidate is rejected" do
      reviewer = user_fixture()

      subject =
        source_ingestion_fixture(%{
          input_type: "pdf",
          status: "needs_duplicate_review",
          processing_stage: "duplicate_review"
        })

      candidate_source = source_ingestion_fixture(%{input_type: "url"})

      assert {:ok, candidate} =
               Ingestions.create_duplicate_candidate(subject, candidate_source, %{
                 evidence: %{"signal" => "minhash"}
               })

      assert {:ok, %{candidate: updated_candidate, source_ingestion: updated_source_ingestion}} =
               Ingestions.reject_duplicate_candidate(candidate, %{reviewed_by_id: reviewer.id})

      assert updated_candidate.status == "rejected"
      assert updated_candidate.reviewed_by_id == reviewer.id
      refute is_nil(updated_candidate.reviewed_at)
      assert updated_source_ingestion.status == "needs_review"
      assert updated_source_ingestion.processing_stage == "review"
    end

    test "refuses to reject a candidate that is no longer pending" do
      reviewer = user_fixture()

      subject =
        source_ingestion_fixture(%{
          input_type: "pdf",
          status: "needs_duplicate_review",
          processing_stage: "duplicate_review"
        })

      candidate_source = source_ingestion_fixture(%{input_type: "url"})

      assert {:ok, candidate} = Ingestions.create_duplicate_candidate(subject, candidate_source)

      assert {:ok, _result} =
               Ingestions.confirm_duplicate_candidate(candidate, %{reviewed_by_id: reviewer.id})

      assert {:error, changeset} =
               Ingestions.reject_duplicate_candidate(candidate, %{reviewed_by_id: reviewer.id})

      assert %{status: ["duplicate review is no longer pending"]} = errors_on(changeset)
    end
  end

  describe "source association and gall-level review" do
    test "keeps species review locked until a source is associated and supports item status transitions" do
      reviewer = user_fixture()
      source = source_fixture()

      ingestion =
        source_ingestion_fixture(%{
          input_type: "pdf",
          status: "needs_review",
          processing_stage: "review"
        })

      refute Ingestions.species_review_unlocked?(ingestion)

      assert {:ok, ingestion} = Ingestions.associate_source(ingestion, source)
      assert Ingestions.species_review_unlocked?(ingestion) == true

      species = species_fixture("Andricus testus")

      assert {:ok, source_ingestion_species} =
               Ingestions.create_source_ingestion_species(%{
                 source_ingestion_id: ingestion.id,
                 position: 0,
                 extracted_name: "Andricus testus",
                 extracted_authority: "Author",
                 description_prose: "Globular leaf gall with a woolly surface.",
                 extraction_payload: %{
                   "hosts" => [%{"name" => "Quercus alba"}],
                   "traits" => %{
                     "shape" => %{"original" => "globular", "suggested" => ["globular"]}
                   }
                 }
               })

      refute Ingestions.all_species_entries_resolved?(ingestion)

      assert {:ok, updated_item} =
               Ingestions.transition_source_ingestion_species_status(
                 source_ingestion_species,
                 :mapped,
                 %{
                   species_id: species.id,
                   reviewed_by_id: reviewer.id,
                   review_payload: %{"decision" => "matched existing species"}
                 }
               )

      assert updated_item.status == "mapped"
      assert updated_item.species_id == species.id
      assert updated_item.reviewed_by_id == reviewer.id
      refute is_nil(updated_item.reviewed_at)
      assert Ingestions.all_species_entries_resolved?(ingestion) == true
    end
  end

  describe "get_source_ingestion_with_details!/1" do
    test "preloads duplicate candidates and species entries in review order" do
      ingestion =
        source_ingestion_fixture(%{
          input_type: "pdf",
          status: "needs_duplicate_review",
          processing_stage: "duplicate_review"
        })

      second_candidate_source = source_ingestion_fixture(%{input_type: "url"})
      first_candidate_source = source_ingestion_fixture(%{input_type: "text"})

      assert {:ok, second_candidate} =
               Ingestions.create_duplicate_candidate(ingestion, second_candidate_source)

      assert {:ok, first_candidate} =
               Ingestions.create_duplicate_candidate(ingestion, first_candidate_source)

      assert {:ok, _rejected_candidate_result} =
               Ingestions.reject_duplicate_candidate(second_candidate, %{
                 reviewed_by_id: user_fixture().id
               })

      assert {:ok, _species_entry} =
               Ingestions.create_source_ingestion_species(%{
                 source_ingestion_id: ingestion.id,
                 position: 2,
                 extracted_name: "Later gall"
               })

      assert {:ok, _species_entry} =
               Ingestions.create_source_ingestion_species(%{
                 source_ingestion_id: ingestion.id,
                 position: 1,
                 extracted_name: "Earlier gall"
               })

      detailed_ingestion = Ingestions.get_source_ingestion_with_details!(ingestion.id)

      assert Enum.map(detailed_ingestion.duplicate_candidates, & &1.id) == [
               first_candidate.id,
               second_candidate.id
             ]

      assert Enum.map(detailed_ingestion.species_entries, & &1.position) == [1, 2]
    end
  end

  defp source_ingestion_fixture(attrs) do
    merged_attrs =
      attrs
      |> Map.new()
      |> Map.put_new(:input_type, "pdf")
      |> Map.put_new(:status, "processing")
      |> Map.put_new(:processing_stage, "submitted")

    assert {:ok, source_ingestion} = Ingestions.create_source_ingestion(merged_attrs)
    source_ingestion
  end

  defp source_fixture do
    assert {:ok, source} =
             Sources.create_source(%{
               title: "Test Source #{System.unique_integer([:positive])}",
               author: "Author",
               pubyear: "2024",
               link: "https://example.com/source",
               citation: "Author. 2024. Test Source.",
               license: "CC-BY",
               licenselink: "https://creativecommons.org/licenses/by/4.0/"
             })

    source
  end

  defp species_fixture(name) do
    assert {:ok, species} =
             Repo.insert(%Species{
               name: name,
               taxoncode: "gall",
               datacomplete: false
             })

    species
  end

  defp user_fixture do
    assert {:ok, user} =
             Accounts.create_user(%{
               auth0_id: "auth0|ingestion-test-#{System.unique_integer([:positive])}",
               display_name: "Ingestion Reviewer"
             })

    user
  end
end
