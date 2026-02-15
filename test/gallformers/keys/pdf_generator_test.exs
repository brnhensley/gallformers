defmodule Gallformers.Keys.PdfGeneratorTest do
  use Gallformers.DataCase

  alias Gallformers.Keys
  alias Gallformers.Keys.PdfGenerator

  @valid_couplets Jason.encode!(%{
                    "1" => %{
                      "leads" => [
                        %{
                          "text" => "Lead A",
                          "images" => [],
                          "destination" => %{"type" => "couplet", "number" => "2"}
                        },
                        %{
                          "text" => "Lead B",
                          "images" => [],
                          "destination" => %{"type" => "taxon", "name" => "Species X"}
                        }
                      ]
                    },
                    "2" => %{
                      "leads" => [
                        %{
                          "text" => "Lead C",
                          "images" => [],
                          "destination" => %{"type" => "taxon", "name" => "Species Y"}
                        },
                        %{
                          "text" => "Lead D",
                          "images" => [],
                          "destination" => %{"type" => "taxon", "name" => "Species Z"}
                        }
                      ]
                    }
                  })

  defp create_test_key do
    {:ok, key} =
      Keys.create_key(%{
        title: "Test Key",
        version: "2026-01-01",
        couplets: @valid_couplets
      })

    key
  end

  describe "serialize_key/1" do
    test "serializes key struct to JSON string" do
      key = create_test_key()
      json = PdfGenerator.serialize_key(key)
      data = Jason.decode!(json)

      assert data["title"] == "Test Key"
      assert data["slug"] == "test-key"
      assert data["version"] == "2026-01-01"
      assert is_map(data["couplets"])
      assert Map.has_key?(data["couplets"], "1")
      assert Map.has_key?(data["couplets"], "2")
    end

    test "couplet leads have string-keyed maps" do
      key = create_test_key()
      json = PdfGenerator.serialize_key(key)
      data = Jason.decode!(json)

      lead = data["couplets"]["1"]["leads"] |> hd()
      assert lead["text"] == "Lead A"
      assert lead["destination"]["type"] == "couplet"
    end
  end

  describe "generate_pdf/2" do
    @tag :typst
    test "generates a PDF file" do
      key = create_test_key()
      {:ok, pdf_path} = PdfGenerator.generate_pdf(key, images: false)

      assert File.exists?(pdf_path)
      # PDF files start with %PDF
      assert File.read!(pdf_path) |> String.starts_with?("%PDF")

      File.rm(pdf_path)
    end

    @tag :typst
    test "returns error when typst is not available" do
      key = create_test_key()
      result = PdfGenerator.generate_pdf(key, images: false, typst_cmd: "nonexistent-binary")

      assert {:error, _reason} = result
    end
  end

  describe "s3_paths/1" do
    test "returns correct S3 paths for a key" do
      key = create_test_key()
      paths = PdfGenerator.s3_paths(key)

      assert paths.text_only == "keys/test-key/test-key.pdf"
      assert paths.with_images == "keys/test-key/test-key-images.pdf"
    end
  end

  describe "cdn_urls/1" do
    test "returns full CDN URLs" do
      key = create_test_key()
      urls = PdfGenerator.cdn_urls(key)

      cdn = Gallformers.Storage.cdn_url()
      assert urls.text_only == "#{cdn}/keys/test-key/test-key.pdf"
      assert urls.with_images == "#{cdn}/keys/test-key/test-key-images.pdf"
    end
  end
end
