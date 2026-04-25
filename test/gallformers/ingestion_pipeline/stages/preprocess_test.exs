defmodule Gallformers.IngestionPipeline.Stages.PreprocessTest do
  use Gallformers.DataCase, async: false

  alias Gallformers.IngestionPipeline.Stages.Preprocess
  alias Gallformers.IngestionPipeline.Storage
  alias Gallformers.Ingestions

  defmodule StorageBackendStub do
    @behaviour Gallformers.IngestionPipeline.Storage.Backend

    @impl true
    def upload(bucket, path, content, content_type) do
      send(test_pid(), {:upload, bucket, path, content, content_type})
      {:ok, %{}}
    end

    @impl true
    def get_object(bucket, path) do
      send(test_pid(), {:get_object, bucket, path})
      {:ok, %{body: Process.get(:extract_text_fixture)}}
    end

    @impl true
    def list_objects(_bucket, _prefix, _continuation_token),
      do: {:ok, %{keys: [], next_continuation_token: nil}}

    @impl true
    def delete_objects(_bucket, _keys), do: {:ok, %{}}

    defp test_pid, do: Process.get(:preprocess_test_pid, self())
  end

  setup do
    previous_storage_config = Application.get_env(:gallformers, Storage)

    Process.put(:preprocess_test_pid, self())
    Application.put_env(:gallformers, Storage, backend: StorageBackendStub)

    on_exit(fn ->
      Process.delete(:preprocess_test_pid)

      if previous_storage_config == nil do
        Application.delete_env(:gallformers, Storage)
      else
        Application.put_env(:gallformers, Storage, previous_storage_config)
      end
    end)

    :ok
  end

  test "downloads extracted text, preprocesses it, persists signals, uploads the artifact, and updates the stage" do
    ingestion = source_ingestion_fixture()
    input_path = "source-ingestions/#{ingestion.id}/extract/text.txt"
    output_path = "source-ingestions/#{ingestion.id}/preprocess/text.txt"

    Process.put(
      :extract_text_fixture,
      """
      https://www.biodiversitylibrary.org/

      Holding Institution: Missouri Botanical Garden
      This page intentionally left blank.

      A biological and systematic study of Philippine galls

      Smith, J.A.

      Published 1919.

      DOI 10.1234/Example.

      This is an ex-
      planation of the text.
      """
    )

    assert {:ok, updated_ingestion} = Preprocess.perform_stage(ingestion)

    assert_received {:get_object, _, ^input_path}

    cleaned_text =
      """
      A biological and systematic study of Philippine galls

      Smith, J.A.

      Published 1919.

      DOI 10.1234/Example.

      This is an explanation of the text.
      """
      |> String.trim()

    assert_received {:upload, _, ^output_path, ^cleaned_text, "text/plain"}

    reloaded_ingestion = Ingestions.get_source_ingestion!(ingestion.id)

    assert updated_ingestion.processing_stage == "preprocess"
    assert reloaded_ingestion.processing_stage == "preprocess"
    assert reloaded_ingestion.status == "processing"

    assert reloaded_ingestion.preprocessed_text_sha256 ==
             compute_sha256(cleaned_text)

    assert reloaded_ingestion.doi == "10.1234/example"
    assert reloaded_ingestion.normalized_doi == "10.1234/example"
    assert reloaded_ingestion.title == "A biological and systematic study of Philippine galls"

    assert reloaded_ingestion.normalized_title ==
             "a biological and systematic study of philippine galls"

    assert reloaded_ingestion.title_fingerprint == "biological_systematic_study_philippine_galls"
    assert reloaded_ingestion.authors == ["Smith, J.A."]
    assert reloaded_ingestion.author_fingerprint == "smith"
    assert reloaded_ingestion.publication_year == 1919
  end

  defp source_ingestion_fixture(attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          input_type: "pdf",
          status: "processing",
          processing_stage: "extract"
        },
        attrs
      )

    {:ok, ingestion} = Ingestions.create_source_ingestion(attrs)
    ingestion
  end

  defp compute_sha256(text) do
    :sha256
    |> :crypto.hash(text)
    |> Base.encode16(case: :lower)
  end
end
