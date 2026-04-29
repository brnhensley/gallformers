defmodule Gallformers.SourcePublisherTest do
  use ExUnit.Case, async: false

  alias Gallformers.Ingestions.SourceIngestion
  alias Gallformers.SourcePublisher
  alias Gallformers.Sources.Source
  alias Gallformers.Storage.SourceArtifacts

  defmodule BackendStub do
    @behaviour Gallformers.Storage.SourceArtifacts.Backend

    @impl true
    def upload(_bucket, _path, _content, _content_type), do: {:ok, %{}}

    @impl true
    def get_object(_bucket, _path), do: {:ok, %{body: ""}}

    @impl true
    def list_objects(_bucket, _prefix, _continuation_token),
      do: {:ok, %{keys: [], next_continuation_token: nil}}

    @impl true
    def delete_objects(_bucket, _keys), do: {:ok, %{}}

    @impl true
    def copy_object(dest_bucket, dest_path, src_bucket, src_path) do
      send(self(), {:copy_object, dest_bucket, dest_path, src_bucket, src_path})

      case Process.get({:object, src_bucket, src_path}) do
        nil ->
          {:error, :not_found}

        object ->
          Process.put({:object, dest_bucket, dest_path}, object)
          {:ok, %{}}
      end
    end
  end

  setup do
    previous_config = Application.get_env(:gallformers, SourceArtifacts)
    Application.put_env(:gallformers, SourceArtifacts, backend: BackendStub)

    on_exit(fn ->
      if previous_config == nil do
        Application.delete_env(:gallformers, SourceArtifacts)
      else
        Application.put_env(:gallformers, SourceArtifacts, previous_config)
      end
    end)

    :ok
  end

  describe "publish_markdown/2" do
    test "copies the assembled private markdown to the public source path byte-for-byte" do
      source = %Source{id: 7, title: "Gall Paper"}
      ingestion = %SourceIngestion{id: 88, artifacts_path: "source-ingestions/88"}
      private_bucket = SourceArtifacts.private_bucket()
      public_bucket = SourceArtifacts.public_bucket()
      private_path = "source-ingestions/88/assemble/output.md"
      markdown = "# Gall Paper\n\nPublished markdown."

      Process.put({:object, private_bucket, private_path}, %{body: markdown})

      assert {:ok, publication} = SourcePublisher.publish_markdown(source, ingestion)

      assert_received {:copy_object, ^public_bucket, "sources/7/gall_paper.md", ^private_bucket,
                       ^private_path}

      assert publication == %{
               bucket: public_bucket,
               path: "sources/7/gall_paper.md",
               url:
                 "https://gallformers-images-us-east-1.s3.amazonaws.com/sources/7/gall_paper.md"
             }

      assert Process.get({:object, public_bucket, "sources/7/gall_paper.md"}) == %{body: markdown}
    end

    test "republishing the same source overwrites the same public key deterministically" do
      source = %Source{id: 7, title: "Gall Paper"}
      ingestion = %SourceIngestion{id: 88, artifacts_path: "source-ingestions/88"}
      private_bucket = SourceArtifacts.private_bucket()
      public_bucket = SourceArtifacts.public_bucket()
      private_path = "source-ingestions/88/assemble/output.md"
      public_path = "sources/7/gall_paper.md"

      Process.put({:object, private_bucket, private_path}, %{body: "first"})
      assert {:ok, first_publication} = SourcePublisher.publish_markdown(source, ingestion)

      Process.put({:object, private_bucket, private_path}, %{body: "second"})
      assert {:ok, second_publication} = SourcePublisher.publish_markdown(source, ingestion)

      assert first_publication.path == public_path
      assert second_publication.path == public_path
      assert Process.get({:object, public_bucket, public_path}) == %{body: "second"}
    end

    test "returns an explicit error when the private assembled markdown is missing" do
      source = %Source{id: 7, title: "Gall Paper"}
      ingestion = %SourceIngestion{id: 88, artifacts_path: "source-ingestions/88"}

      assert {:error, :private_markdown_not_found} =
               SourcePublisher.publish_markdown(source, ingestion)
    end

    test "fails clearly when the ingestion has no artifacts path" do
      source = %Source{id: 7, title: "Gall Paper"}
      ingestion = %SourceIngestion{id: 88, artifacts_path: nil}

      assert {:error, :missing_artifacts_path} =
               SourcePublisher.publish_markdown(source, ingestion)
    end
  end
end
