defmodule Gallformers.GlossariesTest do
  @moduledoc """
  Unit tests for the Glossaries context.
  """
  use Gallformers.DataCase

  alias Gallformers.Glossaries

  # Test seeds provide 4 glossary entries:
  # abscission, bivalved, cynipid, detachable

  describe "list_glossary/0" do
    test "returns all glossary entries" do
      entries = Glossaries.list_glossary()
      assert length(entries) == 4
    end

    test "entries are ordered alphabetically by word" do
      entries = Glossaries.list_glossary()
      words = Enum.map(entries, & &1.word)
      assert words == ["abscission", "bivalved", "cynipid", "detachable"]
    end

    test "entries have expected fields" do
      [entry | _] = Glossaries.list_glossary()
      assert entry.id == 1
      assert entry.word == "abscission"
      assert entry.definition =~ "natural detachment"
    end
  end

  describe "get_glossary/1" do
    test "returns nil for non-existent ID" do
      assert nil == Glossaries.get_glossary(999_999_999)
    end

    test "returns entry for valid ID" do
      entry = Glossaries.get_glossary(1)
      assert entry.word == "abscission"
    end
  end

  describe "get_glossary_by_word/1" do
    test "returns nil for non-existent word" do
      assert nil == Glossaries.get_glossary_by_word("nonexistentwordxyz123")
    end

    test "returns entry for valid word" do
      entry = Glossaries.get_glossary_by_word("cynipid")
      assert entry.id == 3
      assert entry.definition =~ "Cynipidae"
    end
  end

  describe "search_glossary/1" do
    test "returns empty list for non-matching query" do
      results = Glossaries.search_glossary("zzzznonexistent123")
      assert results == []
    end

    test "returns matching entries for valid query" do
      results = Glossaries.search_glossary("cyn")
      assert length(results) >= 1
      assert Enum.any?(results, &(&1.word == "cynipid")) == true
    end

    test "search is case-insensitive" do
      upper_results = Glossaries.search_glossary("CYNIPID")
      lower_results = Glossaries.search_glossary("cynipid")

      assert length(upper_results) > 0
      assert length(upper_results) == length(lower_results)
    end

    test "searches in definitions too" do
      # "detachment" appears in abscission's definition, not its word
      results = Glossaries.search_glossary("detachment")
      assert Enum.any?(results, &(&1.word == "abscission")) == true
    end
  end

  describe "count_glossary/0" do
    test "returns count matching seeded entries" do
      assert Glossaries.count_glossary() == 4
    end

    test "count matches length of list_glossary" do
      count = Glossaries.count_glossary()
      entries = Glossaries.list_glossary()
      assert count == length(entries)
    end
  end

  describe "list_glossary_by_letter/1" do
    test "returns entries starting with specified letter" do
      entries = Glossaries.list_glossary_by_letter("d")
      assert length(entries) == 1
      assert hd(entries).word == "detachable"
    end

    test "is case-insensitive" do
      upper_results = Glossaries.list_glossary_by_letter("A")
      lower_results = Glossaries.list_glossary_by_letter("a")
      assert upper_results == lower_results
    end

    test "returns empty list for letter with no entries" do
      assert Glossaries.list_glossary_by_letter("z") == []
    end
  end

  describe "get_letter_counts/0" do
    test "returns a map with correct counts" do
      counts = Glossaries.get_letter_counts()
      assert counts["A"] == 1
      assert counts["B"] == 1
      assert counts["C"] == 1
      assert counts["D"] == 1
      assert map_size(counts) == 4
    end

    test "map keys are uppercase letters" do
      counts = Glossaries.get_letter_counts()

      Enum.each(counts, fn {letter, _count} ->
        assert String.length(letter) == 1
        assert letter == String.upcase(letter)
      end)
    end

    test "total count matches count_glossary" do
      counts = Glossaries.get_letter_counts()
      total_from_map = Enum.reduce(counts, 0, fn {_l, c}, acc -> acc + c end)
      assert total_from_map == Glossaries.count_glossary()
    end
  end
end
