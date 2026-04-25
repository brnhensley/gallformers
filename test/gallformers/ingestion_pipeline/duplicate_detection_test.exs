defmodule Gallformers.IngestionPipeline.DuplicateDetectionTest do
  use Gallformers.DataCase, async: false

  alias Gallformers.IngestionPipeline.DuplicateDetection
  alias Gallformers.IngestionPipeline.MinHash
  alias Gallformers.Ingestions

  test "exact raw input sha match returns an exact duplicate" do
    candidate =
      source_ingestion_fixture(%{
        raw_input_sha256: String.duplicate("a", 64)
      })

    ingestion =
      source_ingestion_fixture(%{
        raw_input_sha256: String.duplicate("a", 64)
      })

    assert {:exact_duplicate, returned_candidate} =
             DuplicateDetection.run_ladder(ingestion, [candidate])

    assert returned_candidate.id == candidate.id
  end

  test "exact doi match returns an exact duplicate" do
    candidate =
      source_ingestion_fixture(%{
        normalized_doi: "10.1234/example"
      })

    ingestion =
      source_ingestion_fixture(%{
        normalized_doi: "10.1234/example"
      })

    assert {:exact_duplicate, returned_candidate} =
             DuplicateDetection.run_ladder(ingestion, [candidate])

    assert returned_candidate.id == candidate.id
  end

  test "high minhash similarity returns a probable duplicate" do
    base_text =
      Enum.map_join(1..8, " ", fn _ ->
        "oak gall wasp larva inside spherical gall on stem with thick walls and many cells"
      end)

    candidate =
      source_ingestion_fixture(%{
        minhash_signature: MinHash.compute_signature(base_text)
      })

    ingestion =
      source_ingestion_fixture(%{
        minhash_signature: MinHash.compute_signature(base_text <> " oak gall wasp larva on stem")
      })

    assert {:probable_duplicate, returned_candidate, evidence} =
             DuplicateDetection.run_ladder(ingestion, [candidate])

    assert returned_candidate.id == candidate.id

    assert (evidence["match_type"] || evidence[:match_type]) in [
             "minhash_high",
             "minhash_moderate"
           ]

    assert (evidence["similarity"] || evidence[:similarity]) >= 0.7
  end

  test "no signals returns no_match" do
    ingestion = source_ingestion_fixture()
    candidate = source_ingestion_fixture()

    assert :no_match = DuplicateDetection.run_ladder(ingestion, [candidate])
  end

  test "fetch_candidates excludes duplicate_confirmed and failed ingestions" do
    ingestion = source_ingestion_fixture(%{normalized_doi: "10.1/allowed"})
    allowed = source_ingestion_fixture(%{normalized_doi: "10.1/allowed"})

    _duplicate_confirmed =
      source_ingestion_fixture(%{
        status: "duplicate_confirmed",
        normalized_doi: "10.1/allowed"
      })

    _failed =
      source_ingestion_fixture(%{
        status: "failed",
        processing_stage: "failed",
        normalized_doi: "10.1/allowed"
      })

    candidates = DuplicateDetection.fetch_candidates(ingestion)

    assert Enum.map(candidates, & &1.id) == [allowed.id]
  end

  test "fetch_candidates only returns ingestions sharing indexed signals" do
    ingestion =
      source_ingestion_fixture(%{
        normalized_doi: "10.1/shared",
        title_fingerprint: "oak_gall_study",
        normalized_title: "oak gall study"
      })

    doi_match = source_ingestion_fixture(%{normalized_doi: "10.1/shared"})
    title_match = source_ingestion_fixture(%{title_fingerprint: "oak_gall_study"})
    normalized_title_match = source_ingestion_fixture(%{normalized_title: "oak gall study"})
    _unrelated = source_ingestion_fixture(%{normalized_doi: "10.1/unrelated"})

    candidates = DuplicateDetection.fetch_candidates(ingestion)

    assert MapSet.new(Enum.map(candidates, & &1.id)) ==
             MapSet.new([doi_match.id, title_match.id, normalized_title_match.id])
  end

  test "fetch_candidates includes bounded minhash fallback candidates" do
    ingestion =
      source_ingestion_fixture(%{
        minhash_signature: MinHash.compute_signature("oak gall wasp duplicate candidate")
      })

    candidate =
      source_ingestion_fixture(%{
        minhash_signature: MinHash.compute_signature("oak gall wasp duplicate candidate")
      })

    assert Enum.map(DuplicateDetection.fetch_candidates(ingestion), & &1.id) == [candidate.id]
  end

  test "fetch_candidates merges indexed signal matches with minhash-only candidates" do
    shared_text =
      "oak gall wasp larva inside spherical gall on stem with thick walls and many cells"

    ingestion =
      source_ingestion_fixture(%{
        normalized_doi: "10.1/shared",
        minhash_signature: MinHash.compute_signature(shared_text)
      })

    doi_match = source_ingestion_fixture(%{normalized_doi: "10.1/shared"})

    minhash_only_match =
      source_ingestion_fixture(%{
        minhash_signature: MinHash.compute_signature(shared_text <> " repeated repeated")
      })

    assert MapSet.new(Enum.map(DuplicateDetection.fetch_candidates(ingestion), & &1.id)) ==
             MapSet.new([doi_match.id, minhash_only_match.id])
  end

  defp source_ingestion_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    status = Map.get(attrs, :status, "processing")

    attrs =
      attrs
      |> Map.put_new(:input_type, "pdf")
      |> Map.put_new(:status, status)
      |> Map.put_new(:processing_stage, default_processing_stage(status))

    {:ok, ingestion} = Ingestions.create_source_ingestion(attrs)
    ingestion
  end

  defp default_processing_stage("duplicate_confirmed"), do: "duplicate_review"
  defp default_processing_stage("failed"), do: "failed"
  defp default_processing_stage(_status), do: "preprocess"
end
