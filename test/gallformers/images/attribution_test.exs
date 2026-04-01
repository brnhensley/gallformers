defmodule Gallformers.Images.AttributionTest do
  @moduledoc """
  Unit tests for the Images.Attribution module.
  """
  use ExUnit.Case, async: true

  alias Gallformers.Images.Attribution

  describe "requires_attribution?/1" do
    test "returns false for Public Domain / CC0" do
      refute Attribution.requires_attribution?("Public Domain / CC0")
    end

    test "returns false for nil" do
      refute Attribution.requires_attribution?(nil)
    end

    test "returns true for CC-BY licenses" do
      assert Attribution.requires_attribution?("CC-BY") == true
      assert Attribution.requires_attribution?("CC-BY-SA") == true
      assert Attribution.requires_attribution?("CC-BY-NC") == true
      assert Attribution.requires_attribution?("CC-BY-NC-SA") == true
      assert Attribution.requires_attribution?("CC-BY-ND") == true
      assert Attribution.requires_attribution?("CC-BY-NC-ND") == true
    end

    test "returns true for All Rights Reserved" do
      assert Attribution.requires_attribution?("All Rights Reserved") == true
    end

    test "returns false for invalid license strings" do
      refute Attribution.requires_attribution?("invalid")
      refute Attribution.requires_attribution?("cc-by")
    end
  end

  describe "image_attributed?/1" do
    test "returns true for Public Domain / CC0 without creator" do
      image = %{
        license: "Public Domain / CC0",
        creator: nil,
        source_id: nil,
        source: nil
      }

      assert Attribution.image_attributed?(image) == true
    end

    test "returns true for CC-BY with creator" do
      image = %{
        license: "CC-BY",
        creator: "John Doe",
        source_id: nil,
        source: nil
      }

      assert Attribution.image_attributed?(image) == true
    end

    test "returns false for CC-BY without creator" do
      image = %{
        license: "CC-BY",
        creator: nil,
        source_id: nil,
        source: nil
      }

      refute Attribution.image_attributed?(image)
    end

    test "returns false for CC-BY with empty creator" do
      image = %{
        license: "CC-BY",
        creator: "",
        source_id: nil,
        source: nil
      }

      refute Attribution.image_attributed?(image)
    end

    test "returns false for CC-BY with whitespace-only creator" do
      image = %{
        license: "CC-BY",
        creator: "   ",
        source_id: nil,
        source: nil
      }

      refute Attribution.image_attributed?(image)
    end

    test "returns false for no license" do
      image = %{
        license: nil,
        creator: "John Doe",
        source_id: nil,
        source: nil
      }

      refute Attribution.image_attributed?(image)
    end

    test "returns true for image with source that has license" do
      image = %{
        license: nil,
        creator: nil,
        source_id: 1,
        source: %{license: "CC-BY"}
      }

      assert Attribution.image_attributed?(image) == true
    end

    test "works with struct (Image schema)" do
      image = %Gallformers.Images.Image{
        license: "CC-BY",
        creator: "Jane Doe",
        source_id: nil,
        source: nil
      }

      assert Attribution.image_attributed?(image) == true
    end
  end

  describe "attribution_fields/0" do
    test "returns list of attribution field names" do
      fields = Attribution.attribution_fields()
      assert is_list(fields)
      assert :creator in fields
      assert :license in fields
      assert :licenselink in fields
      assert :sourcelink in fields
      assert :attribution in fields
      assert :caption in fields
    end
  end
end
