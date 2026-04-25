defmodule Gallformers.IngestionPipeline.StorageTest do
  use ExUnit.Case, async: false

  alias Gallformers.IngestionPipeline.Storage

  defmodule BackendStub do
    @behaviour Gallformers.IngestionPipeline.Storage.Backend

    @impl true
    def upload(bucket, path, content, content_type) do
      send(self(), {:upload, bucket, path, content, content_type})
      Process.get(:upload_result, {:ok, %{}})
    end

    @impl true
    def get_object(bucket, path) do
      send(self(), {:get_object, bucket, path})
      Process.get(:get_object_result, {:ok, %{body: ""}})
    end

    @impl true
    def list_objects(bucket, prefix, continuation_token) do
      send(self(), {:list_objects, bucket, prefix, continuation_token})

      case Process.get(:list_objects_results, [{:ok, %{keys: [], next_continuation_token: nil}}]) do
        [next_result | rest] ->
          Process.put(:list_objects_results, rest)
          next_result

        [] ->
          {:ok, %{keys: [], next_continuation_token: nil}}
      end
    end

    @impl true
    def delete_objects(bucket, keys) do
      send(self(), {:delete_objects, bucket, keys})
      Process.get(:delete_objects_result, {:ok, %{}})
    end
  end

  setup do
    previous_config = Application.get_env(:gallformers, Storage)
    Application.put_env(:gallformers, Storage, backend: BackendStub)

    on_exit(fn ->
      if previous_config == nil do
        Application.delete_env(:gallformers, Storage)
      else
        Application.put_env(:gallformers, Storage, previous_config)
      end
    end)

    :ok
  end

  describe "artifact_path/3" do
    test "generates the canonical source-ingestions S3 key" do
      assert Storage.artifact_path(42, :extract, "text.txt") ==
               "source-ingestions/42/extract/text.txt"
    end
  end

  describe "upload_artifact/5" do
    test "uploads to the private bucket using the artifact path" do
      bucket = Storage.private_bucket()

      assert {:ok, path} =
               Storage.upload_artifact(42, :preprocess, "text.txt", "cleaned text", "text/plain")

      assert path == "source-ingestions/42/preprocess/text.txt"

      assert_received {:upload, ^bucket, "source-ingestions/42/preprocess/text.txt",
                       "cleaned text", "text/plain"}
    end
  end

  describe "download_artifact/3" do
    test "returns artifact contents" do
      bucket = Storage.private_bucket()
      Process.put(:get_object_result, {:ok, %{body: "artifact contents"}})

      assert {:ok, "artifact contents"} =
               Storage.download_artifact(42, :metadata, "output.json")

      assert_received {:get_object, ^bucket, "source-ingestions/42/metadata/output.json"}
    end

    test "normalizes missing object errors to not_found" do
      Process.put(:get_object_result, {:error, {:http_error, 404, "missing"}})

      assert {:error, :not_found} =
               Storage.download_artifact(42, :metadata, "missing.json")
    end
  end

  describe "delete_artifacts_for_ingestion/1" do
    test "lists all objects under the ingestion prefix and deletes them in a batch" do
      bucket = Storage.private_bucket()

      Process.put(:list_objects_results, [
        {:ok,
         %{
           keys: ["source-ingestions/42/extract/text.txt"],
           next_continuation_token: "page-2"
         }},
        {:ok,
         %{
           keys: [
             "source-ingestions/42/preprocess/text.txt",
             "source-ingestions/42/metadata/output.json"
           ],
           next_continuation_token: nil
         }}
      ])

      assert :ok = Storage.delete_artifacts_for_ingestion(42)

      assert_received {:list_objects, ^bucket, "source-ingestions/42/", nil}
      assert_received {:list_objects, ^bucket, "source-ingestions/42/", "page-2"}

      assert_received {:delete_objects, ^bucket, keys}

      assert Enum.sort(keys) == [
               "source-ingestions/42/extract/text.txt",
               "source-ingestions/42/metadata/output.json",
               "source-ingestions/42/preprocess/text.txt"
             ]
    end
  end
end
