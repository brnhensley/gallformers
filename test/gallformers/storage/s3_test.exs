defmodule Gallformers.Storage.S3Test do
  use ExUnit.Case, async: true

  alias Gallformers.Storage.S3

  describe "presigned_url/4" do
    test "returns a deterministic mock URL when S3 is disabled" do
      assert {:ok, url} =
               S3.presigned_url(:put, "example-bucket", "articles/42/image one.jpg",
                 expires_in: 300,
                 query_params: [{"Content-Type", "image/jpeg"}]
               )

      assert url ==
               "https://example.test/mock-s3/example-bucket/articles/42/image%20one.jpg?method=PUT"
    end
  end

  describe "request/1" do
    test "returns a mock success response when S3 is disabled" do
      operation = ExAws.S3.list_objects("example-bucket", prefix: "articles/")

      assert {:ok, %{body: %{contents: [], is_truncated: false}}} = S3.request(operation)
    end
  end
end
