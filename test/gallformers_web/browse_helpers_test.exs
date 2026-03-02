defmodule GallformersWeb.BrowseHelpersTest do
  use ExUnit.Case, async: true

  alias GallformersWeb.BrowseHelpers

  describe "toggle_set/2" do
    test "adds key when absent" do
      set = MapSet.new(["a", "b"])
      assert BrowseHelpers.toggle_set(set, "c") == MapSet.new(["a", "b", "c"])
    end

    test "removes key when present" do
      set = MapSet.new(["a", "b", "c"])
      assert BrowseHelpers.toggle_set(set, "b") == MapSet.new(["a", "c"])
    end

    test "works with empty set" do
      set = MapSet.new()
      assert BrowseHelpers.toggle_set(set, "x") == MapSet.new(["x"])
    end
  end
end
