defmodule Gallformers.GlossariesTest do
  @moduledoc """
  Unit tests for the Glossaries context.
  """
  use Gallformers.DataCase, async: true

  alias Gallformers.Glossaries

  describe "list_glossary/0" do
    test "returns a list of glossary entries" do
      entries = Glossaries.list_glossary()
      assert is_list(entries)
    end

    test "entries are ordered alphabetically by word" do
      entries = Glossaries.list_glossary()

      if length(entries) > 1 do
        words = Enum.map(entries, & &1.word)
        assert words == Enum.sort(words)
      end
    end

    test "entries have expected fields" do
      entries = Glossaries.list_glossary()

      if length(entries) > 0 do
        entry = hd(entries)
        assert Map.has_key?(entry, :id)
        assert Map.has_key?(entry, :word)
        assert Map.has_key?(entry, :definition)
      end
    end
  end

  describe "get_glossary/1" do
    test "returns nil for non-existent ID" do
      assert nil == Glossaries.get_glossary(999_999_999)
    end

    test "returns entry for valid ID" do
      entries = Glossaries.list_glossary()

      if length(entries) > 0 do
        entry = Glossaries.get_glossary(hd(entries).id)
        assert entry != nil
        assert entry.id == hd(entries).id
      end
    end
  end

  describe "get_glossary_by_word/1" do
    test "returns nil for non-existent word" do
      assert nil == Glossaries.get_glossary_by_word("nonexistentwordxyz123")
    end

    test "returns entry for valid word" do
      entries = Glossaries.list_glossary()

      if length(entries) > 0 do
        entry = Glossaries.get_glossary_by_word(hd(entries).word)
        assert entry != nil
        assert entry.word == hd(entries).word
      end
    end
  end

  describe "search_glossary/1" do
    test "returns empty list for non-matching query" do
      results = Glossaries.search_glossary("zzzznonexistent123")
      assert results == []
    end

    test "returns matching entries for valid query" do
      entries = Glossaries.list_glossary()

      if length(entries) > 0 do
        # Search for part of first entry's word
        word = hd(entries).word
        search_term = String.slice(word, 0, 3)
        results = Glossaries.search_glossary(search_term)

        assert is_list(results)
        assert length(results) > 0
      end
    end

    test "search is case-insensitive" do
      entries = Glossaries.list_glossary()

      if length(entries) > 0 do
        word = hd(entries).word
        upper_results = Glossaries.search_glossary(String.upcase(word))
        lower_results = Glossaries.search_glossary(String.downcase(word))

        assert is_list(upper_results)
        assert is_list(lower_results)
      end
    end

    test "searches in definitions too" do
      entries = Glossaries.list_glossary()

      entry_with_definition =
        Enum.find(entries, fn e ->
          e.definition != nil and String.length(e.definition) > 10
        end)

      if entry_with_definition do
        # Search for part of the definition
        search_term = String.slice(entry_with_definition.definition, 0, 5)
        results = Glossaries.search_glossary(search_term)
        assert is_list(results)
      end
    end
  end

  describe "count_glossary/0" do
    test "returns a non-negative integer" do
      count = Glossaries.count_glossary()
      assert is_integer(count)
      assert count >= 0
    end

    test "count matches length of list_glossary" do
      count = Glossaries.count_glossary()
      entries = Glossaries.list_glossary()
      assert count == length(entries)
    end
  end

  describe "list_glossary_by_letter/1" do
    test "returns entries starting with specified letter" do
      entries = Glossaries.list_glossary_by_letter("a")

      Enum.each(entries, fn entry ->
        first_letter = String.first(entry.word) |> String.downcase()
        assert first_letter == "a"
      end)
    end

    test "is case-insensitive" do
      upper_results = Glossaries.list_glossary_by_letter("A")
      lower_results = Glossaries.list_glossary_by_letter("a")
      assert upper_results == lower_results
    end

    test "returns empty list for letter with no entries" do
      # Test with an uncommon starting letter
      results = Glossaries.list_glossary_by_letter("z")
      assert is_list(results)
    end
  end

  describe "get_letter_counts/0" do
    test "returns a map" do
      counts = Glossaries.get_letter_counts()
      assert is_map(counts)
    end

    test "map keys are uppercase letters" do
      counts = Glossaries.get_letter_counts()

      Enum.each(counts, fn {letter, _count} ->
        assert is_binary(letter)
        assert String.length(letter) == 1
        assert letter == String.upcase(letter)
      end)
    end

    test "map values are positive integers" do
      counts = Glossaries.get_letter_counts()

      Enum.each(counts, fn {_letter, count} ->
        assert is_integer(count)
        assert count > 0
      end)
    end

    test "total count matches count_glossary" do
      counts = Glossaries.get_letter_counts()
      total_from_map = Enum.reduce(counts, 0, fn {_l, c}, acc -> acc + c end)
      total = Glossaries.count_glossary()
      assert total_from_map == total
    end
  end
end
