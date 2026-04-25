defmodule Gallformers.IngestionPipeline.Stages.HashAndDedupTest do
  use Gallformers.DataCase, async: false

  alias Gallformers.IngestionPipeline.Broadcaster
  alias Gallformers.IngestionPipeline.MinHash
  alias Gallformers.IngestionPipeline.Stages.HashAndDedup
  alias Gallformers.IngestionPipeline.Storage
  alias Gallformers.Ingestions

  defmodule StorageBackendStub do
    @behaviour Gallformers.IngestionPipeline.Storage.Backend

    @impl true
    def upload(_bucket, _path, _content, _content_type), do: {:ok, %{}}

    @impl true
    def get_object(bucket, path) do
      send(test_pid(), {:get_object, bucket, path})
      {:ok, %{body: Process.get(:preprocess_text_fixture)}}
    end

    @impl true
    def list_objects(_bucket, _prefix, _continuation_token),
      do: {:ok, %{keys: [], next_continuation_token: nil}}

    @impl true
    def delete_objects(_bucket, _keys), do: {:ok, %{}}

    defp test_pid, do: Process.get(:hash_and_dedup_test_pid, self())
  end

  setup do
    previous_storage_config = Application.get_env(:gallformers, Storage)

    Process.put(:hash_and_dedup_test_pid, self())
    Application.put_env(:gallformers, Storage, backend: StorageBackendStub)

    on_exit(fn ->
      Process.delete(:hash_and_dedup_test_pid)

      if previous_storage_config == nil do
        Application.delete_env(:gallformers, Storage)
      else
        Application.put_env(:gallformers, Storage, previous_storage_config)
      end
    end)

    :ok
  end

  test "auto-confirm path sets duplicate_confirmed and creates an auto_confirmed candidate" do
    Process.put(
      :preprocess_text_fixture,
      "oak gall text with many repeated terms for minhash stability"
    )

    canonical =
      source_ingestion_fixture(%{
        raw_input_sha256: String.duplicate("a", 64),
        preprocessed_text_sha256: String.duplicate("b", 64)
      })

    ingestion =
      source_ingestion_fixture(%{
        raw_input_sha256: String.duplicate("a", 64),
        preprocessed_text_sha256: String.duplicate("c", 64)
      })

    ingestion_id = ingestion.id
    assert :ok = Broadcaster.subscribe(ingestion.id)
    assert {:ok, updated_ingestion} = HashAndDedup.perform_stage(ingestion)

    assert updated_ingestion.status == "duplicate_confirmed"
    assert updated_ingestion.processing_stage == "duplicate_review"
    assert updated_ingestion.duplicate_of_source_ingestion_id == canonical.id

    [candidate_record] = Ingestions.list_duplicate_candidates(ingestion)
    assert candidate_record.status == "auto_confirmed"
    assert candidate_record.candidate_source_ingestion_id == canonical.id

    assert_receive {:stage_complete, :hash_and_dedup}
    assert_receive {:review_ready, ^ingestion_id}
  end

  test "probable match path creates pending candidate records and pauses for duplicate review" do
    Process.put(
      :preprocess_text_fixture,
      "oak gall text with many repeated terms for minhash stability"
    )

    candidate =
      source_ingestion_fixture(%{
        title_fingerprint: "oak_gall_study",
        author_fingerprint: "smith",
        publication_year: 1919
      })

    ingestion =
      source_ingestion_fixture(%{
        title_fingerprint: "oak_gall_study",
        author_fingerprint: "smith",
        publication_year: 1919
      })

    assert :ok = Broadcaster.subscribe(ingestion.id)
    assert {:ok, updated_ingestion} = HashAndDedup.perform_stage(ingestion)

    assert updated_ingestion.status == "needs_duplicate_review"
    assert updated_ingestion.processing_stage == "duplicate_review"

    [candidate_record] = Ingestions.list_duplicate_candidates(ingestion)
    assert candidate_record.status == "pending"
    assert candidate_record.candidate_source_ingestion_id == candidate.id
    assert candidate_record.evidence["match_type"] == "strong_bibliographic"

    assert_receive {:needs_duplicate_review, [broadcast_candidate]}
    assert broadcast_candidate.id == candidate_record.id
  end

  test "minhash-only probable matches still pause for duplicate review" do
    base_text =
      Enum.map_join(1..8, " ", fn _ ->
        "oak gall wasp larva inside spherical gall on stem with thick walls and many cells"
      end)

    Process.put(:preprocess_text_fixture, base_text <> " oak gall wasp larva on stem")

    candidate =
      source_ingestion_fixture(%{
        minhash_signature: MinHash.compute_signature(base_text)
      })

    ingestion = source_ingestion_fixture()

    assert :ok = Broadcaster.subscribe(ingestion.id)
    assert {:ok, updated_ingestion} = HashAndDedup.perform_stage(ingestion)

    assert updated_ingestion.status == "needs_duplicate_review"
    assert updated_ingestion.processing_stage == "duplicate_review"

    [candidate_record] = Ingestions.list_duplicate_candidates(ingestion)
    assert candidate_record.status == "pending"
    assert candidate_record.candidate_source_ingestion_id == candidate.id

    assert candidate_record.evidence["match_type"] in ["minhash_high", "minhash_moderate"]
    assert candidate_record.evidence["similarity"] >= 0.7

    assert_receive {:needs_duplicate_review, [broadcast_candidate]}
    assert broadcast_candidate.id == candidate_record.id
  end

  test "no match path stores the signature and advances to hash_and_dedup" do
    text =
      "oak gall wasp larva inside spherical gall on stem with thick walls and many cells repeated repeated"

    Process.put(:preprocess_text_fixture, text)

    ingestion = source_ingestion_fixture()

    assert :ok = Broadcaster.subscribe(ingestion.id)
    assert {:ok, updated_ingestion} = HashAndDedup.perform_stage(ingestion)

    assert updated_ingestion.status == "processing"
    assert updated_ingestion.processing_stage == "hash_and_dedup"

    reloaded_ingestion = Ingestions.get_source_ingestion!(ingestion.id)
    assert reloaded_ingestion.minhash_signature == MinHash.compute_signature(text)

    assert_receive {:stage_complete, :hash_and_dedup}
  end

  defp source_ingestion_fixture(attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          input_type: "pdf",
          status: "processing",
          processing_stage: "preprocess"
        },
        attrs
      )

    {:ok, ingestion} = Ingestions.create_source_ingestion(attrs)
    ingestion
  end
end
