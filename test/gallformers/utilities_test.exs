defmodule Gallformers.UtilitiesTest do
  use ExUnit.Case, async: true

  alias Gallformers.Utilities

  describe "all_caps?/1" do
    test "returns true for all uppercase text" do
      assert Utilities.all_caps?("HELLO WORLD") == true
    end

    test "returns false for all lowercase text" do
      refute Utilities.all_caps?("hello world")
    end

    test "returns false for mixed case text" do
      refute Utilities.all_caps?("Hello World")
    end

    test "returns false for single lowercase letter" do
      refute Utilities.all_caps?("a")
    end

    test "returns true for single uppercase letter" do
      assert Utilities.all_caps?("A") == true
    end

    test "returns false for empty string" do
      refute Utilities.all_caps?("")
    end

    test "returns true for uppercase with numbers" do
      assert Utilities.all_caps?("CHAPTER 1") == true
    end

    test "returns true for all uppercase with punctuation" do
      assert Utilities.all_caps?("HELLO, WORLD!") == true
    end

    test "handles strings with only spaces" do
      refute Utilities.all_caps?("   ")
    end

    test "handles strings with only special characters" do
      refute Utilities.all_caps?("...!!!")
    end
  end
end
