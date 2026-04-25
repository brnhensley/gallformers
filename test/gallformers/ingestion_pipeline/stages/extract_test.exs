defmodule Gallformers.IngestionPipeline.Stages.ExtractTest do
  use Gallformers.DataCase, async: false

  alias Gallformers.IngestionPipeline.Stages.Extract
  alias Gallformers.IngestionPipeline.Storage
  alias Gallformers.Ingestions

  defmodule StorageBackendStub do
    @behaviour Gallformers.IngestionPipeline.Storage.Backend

    @impl true
    def upload(bucket, path, content, content_type) do
      send(test_pid(), {:upload, bucket, path, content, content_type})
      Process.get(:upload_result, {:ok, %{}})
    end

    @impl true
    def get_object(bucket, path) do
      send(test_pid(), {:get_object, bucket, path})
      Process.get(:get_object_result, {:ok, %{body: "%PDF-1.4\nfixture\n"}})
    end

    @impl true
    def list_objects(_bucket, _prefix, _continuation_token),
      do: {:ok, %{keys: [], next_continuation_token: nil}}

    @impl true
    def delete_objects(_bucket, _keys), do: {:ok, %{}}

    defp test_pid, do: Process.get(:extract_test_pid, self())
  end

  defmodule ExtractorStub do
    def extract_text(file_path, opts) do
      send(test_pid(), {:extractor_extract, file_path, opts, File.read!(file_path)})

      Process.get(
        :extractor_result,
        {:ok, %{text: "extracted text", page_count: 2, metadata: %{}}}
      )
    end

    defp test_pid, do: Process.get(:extract_test_pid, self())
  end

  setup do
    previous_storage_config = Application.get_env(:gallformers, Storage)
    previous_extract_config = Application.get_env(:gallformers, Extract)

    Process.put(:extract_test_pid, self())
    Application.put_env(:gallformers, Storage, backend: StorageBackendStub)
    Application.put_env(:gallformers, Extract, extractor: ExtractorStub)

    on_exit(fn ->
      Process.delete(:extract_test_pid)

      if previous_storage_config == nil do
        Application.delete_env(:gallformers, Storage)
      else
        Application.put_env(:gallformers, Storage, previous_storage_config)
      end

      if previous_extract_config == nil do
        Application.delete_env(:gallformers, Extract)
      else
        Application.put_env(:gallformers, Extract, previous_extract_config)
      end
    end)

    :ok
  end

  describe "perform_stage/1" do
    test "downloads the input pdf, extracts text, uploads the artifact, and updates the stage" do
      ingestion = source_ingestion_fixture()
      input_path = "source-ingestions/#{ingestion.id}/input/source.pdf"
      output_path = "source-ingestions/#{ingestion.id}/extract/text.txt"

      assert {:ok, updated_ingestion} = Extract.perform_stage(ingestion)

      assert_received {:get_object, _, ^input_path}

      assert_received {:extractor_extract, temp_file_path, [ocr_fallback: false],
                       "%PDF-1.4\nfixture\n"}

      refute File.exists?(temp_file_path)

      assert_received {:upload, _, ^output_path, "extracted text", "text/plain"}

      assert updated_ingestion.processing_stage == "extract"
      assert updated_ingestion.status == "processing"
    end

    test "returns extractor errors without updating the ingestion" do
      ingestion = source_ingestion_fixture()
      Process.put(:extractor_result, {:error, :extraction_failed, :boom})

      assert {:error, :extraction_failed, :boom} = Extract.perform_stage(ingestion)

      reloaded_ingestion = Ingestions.get_source_ingestion!(ingestion.id)
      assert reloaded_ingestion.processing_stage == "submitted"
      assert reloaded_ingestion.status == "processing"
    end

    test "rejects unsupported input types" do
      ingestion = source_ingestion_fixture(%{input_type: "url"})

      assert {:error, :unsupported_input_type} = Extract.perform_stage(ingestion)
    end
  end

  defp source_ingestion_fixture(attrs \\ %{}) do
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
end
