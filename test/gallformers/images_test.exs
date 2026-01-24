defmodule Gallformers.ImagesTest do
  @moduledoc """
  Unit tests for the Images context.
  """
  use Gallformers.DataCase, async: false

  alias Gallformers.Images
  alias Gallformers.Species.Image

  describe "parse_species_id_from_path/1" do
    test "extracts species_id from valid gall path" do
      assert {:ok, 123} =
               Images.parse_species_id_from_path("gall/123/123_1234567890_original.jpg")

      assert {:ok, 1} = Images.parse_species_id_from_path("gall/1/1_1234567890_original.png")
      assert {:ok, 99999} = Images.parse_species_id_from_path("gall/99999/some_file.jpg")
    end

    test "returns error for non-gall paths" do
      assert {:error, :invalid_path} = Images.parse_species_id_from_path("articles/1/image.jpg")
      assert {:error, :invalid_path} = Images.parse_species_id_from_path("other/123/image.jpg")
    end

    test "returns error for invalid species_id" do
      assert {:error, :invalid_path} = Images.parse_species_id_from_path("gall/abc/image.jpg")
      assert {:error, :invalid_path} = Images.parse_species_id_from_path("gall/12.5/image.jpg")
    end

    test "returns error for malformed paths" do
      assert {:error, :invalid_path} = Images.parse_species_id_from_path("gall")
      assert {:error, :invalid_path} = Images.parse_species_id_from_path("")
      assert {:error, :invalid_path} = Images.parse_species_id_from_path("image.jpg")
    end
  end

  describe "requires_attribution?/1" do
    test "returns false for Public Domain / CC0" do
      refute Images.requires_attribution?("Public Domain / CC0")
    end

    test "returns false for nil" do
      refute Images.requires_attribution?(nil)
    end

    test "returns true for CC-BY licenses" do
      assert Images.requires_attribution?("CC-BY")
      assert Images.requires_attribution?("CC-BY-SA")
      assert Images.requires_attribution?("CC-BY-NC")
      assert Images.requires_attribution?("CC-BY-NC-SA")
      assert Images.requires_attribution?("CC-BY-ND")
      assert Images.requires_attribution?("CC-BY-NC-ND")
    end

    test "returns true for All Rights Reserved" do
      assert Images.requires_attribution?("All Rights Reserved")
    end

    test "returns false for invalid license strings" do
      refute Images.requires_attribution?("invalid")
      refute Images.requires_attribution?("cc-by")
    end
  end

  describe "image_attributed?/1" do
    test "returns true for Public Domain / CC0 without creator" do
      image = %Image{
        license: "Public Domain / CC0",
        creator: nil,
        source_id: nil,
        source: nil
      }

      assert Images.image_attributed?(image)
    end

    test "returns true for CC-BY with creator" do
      image = %Image{
        license: "CC-BY",
        creator: "John Doe",
        source_id: nil,
        source: nil
      }

      assert Images.image_attributed?(image)
    end

    test "returns false for CC-BY without creator" do
      image = %Image{
        license: "CC-BY",
        creator: nil,
        source_id: nil,
        source: nil
      }

      refute Images.image_attributed?(image)
    end

    test "returns false for CC-BY with empty creator" do
      image = %Image{
        license: "CC-BY",
        creator: "",
        source_id: nil,
        source: nil
      }

      refute Images.image_attributed?(image)
    end

    test "returns false for CC-BY with whitespace-only creator" do
      image = %Image{
        license: "CC-BY",
        creator: "   ",
        source_id: nil,
        source: nil
      }

      refute Images.image_attributed?(image)
    end

    test "returns false for no license" do
      image = %Image{
        license: nil,
        creator: "John Doe",
        source_id: nil,
        source: nil
      }

      refute Images.image_attributed?(image)
    end

    test "returns true for image with source that has license" do
      source = %Gallformers.Sources.Source{
        id: 1,
        license: "CC-BY"
      }

      image = %Image{
        license: nil,
        creator: nil,
        source_id: 1,
        source: source
      }

      assert Images.image_attributed?(image)
    end
  end

  describe "find_orphan_paths/1" do
    test "returns empty list for empty input" do
      assert [] = Images.find_orphan_paths([])
    end

    test "identifies paths with non-existent species as orphans" do
      # Use a species ID that definitely doesn't exist
      s3_objects = [
        %{key: "gall/999999999/999999999_1234567890_original.jpg", last_modified: nil, size: 1000}
      ]

      orphans = Images.find_orphan_paths(s3_objects)
      assert length(orphans) == 1
      assert hd(orphans).species_exists == false
    end
  end

  describe "list_unattributed_images/1" do
    test "returns tuple with images and count" do
      {images, count} = Images.list_unattributed_images()
      assert is_list(images)
      assert is_integer(count)
      assert count >= 0
    end

    test "respects pagination options" do
      {images, _count} = Images.list_unattributed_images(page: 1, per_page: 5)
      assert length(images) <= 5
    end
  end

  describe "count_unattributed_images/0" do
    test "returns a non-negative integer" do
      count = Images.count_unattributed_images()
      assert is_integer(count)
      assert count >= 0
    end
  end
end
