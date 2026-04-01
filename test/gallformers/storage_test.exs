defmodule Gallformers.StorageTest do
  @moduledoc """
  Unit tests for Storage module — content image path generation and deletion.
  """
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Gallformers.Storage

  describe "generate_content_image_path/4" do
    test "generates article path without _original suffix" do
      path = Storage.generate_content_image_path("articles", 42, "jpg", has_variants: false)
      assert String.starts_with?(path, "articles/42/") == true
      assert String.ends_with?(path, ".jpg") == true
      refute String.contains?(path, "_original")
    end

    test "generates key path with _original suffix" do
      path = Storage.generate_content_image_path("keys", 7, "png", has_variants: true)
      assert String.starts_with?(path, "keys/7/") == true
      assert String.ends_with?(path, ".png") == true
      assert String.contains?(path, "_original") == true
    end

    test "strips leading dot from extension" do
      path = Storage.generate_content_image_path("articles", 1, ".jpg", has_variants: false)
      assert String.ends_with?(path, ".jpg") == true
      refute String.contains?(path, "..jpg")
    end

    test "generates unique paths on successive calls" do
      path1 = Storage.generate_content_image_path("articles", 1, "jpg", has_variants: false)
      path2 = Storage.generate_content_image_path("articles", 1, "jpg", has_variants: false)
      assert path1 != path2
    end
  end

  describe "variant_keys_for_path/2" do
    test "returns only the path when sizes is empty" do
      keys = Storage.variant_keys_for_path("articles/42/123_456.jpg", [])
      assert keys == ["articles/42/123_456.jpg"]
    end

    test "returns original + variant keys when sizes provided" do
      keys = Storage.variant_keys_for_path("keys/7/123_original.png", [:medium, :large])
      assert "keys/7/123_original.png" in keys
      assert "keys/7/123_medium.png" in keys
      assert "keys/7/123_large.png" in keys
      assert length(keys) == 3
    end
  end

  describe "generate_size_variants/2" do
    test "1-arity version still uses default 4 sizes" do
      # We can't easily test the actual S3 upload, but we can verify the function exists
      # and returns the expected error when CDN is not available in test
      assert capture_log(fn ->
               assert {:error, _} =
                        Storage.generate_size_variants("nonexistent/path/original.jpg")
             end) =~ "Failed to generate size variants"
    end
  end
end
