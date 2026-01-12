defmodule Gallformers.SpeciesTest do
  @moduledoc """
  Unit tests for the Species context.
  """
  use Gallformers.DataCase, async: true

  alias Gallformers.Species

  describe "list_species/0" do
    test "returns a list of species" do
      species = Species.list_species()
      assert is_list(species)
    end
  end

  describe "list_galls/0" do
    test "returns galls with expected fields" do
      galls = Species.list_galls()
      assert is_list(galls)

      if length(galls) > 0 do
        gall = hd(galls)
        assert Map.has_key?(gall, :id)
        assert Map.has_key?(gall, :name)
        assert Map.has_key?(gall, :taxoncode)
        assert gall.taxoncode == "gall"
      end
    end

    test "returns galls ordered by name" do
      galls = Species.list_galls()

      if length(galls) > 1 do
        names = Enum.map(galls, & &1.name)
        assert names == Enum.sort(names)
      end
    end
  end

  describe "list_galls_paginated/2" do
    test "returns limited number of galls" do
      galls = Species.list_galls_paginated(5, 0)
      assert length(galls) <= 5
    end

    test "respects offset parameter" do
      all_galls = Species.list_galls()

      if length(all_galls) > 5 do
        first_page = Species.list_galls_paginated(5, 0)
        second_page = Species.list_galls_paginated(5, 5)

        # Ensure no overlap
        first_ids = MapSet.new(Enum.map(first_page, & &1.id))
        second_ids = MapSet.new(Enum.map(second_page, & &1.id))
        assert MapSet.disjoint?(first_ids, second_ids)
      end
    end
  end

  describe "count_galls/0" do
    test "returns a non-negative integer" do
      count = Species.count_galls()
      assert is_integer(count)
      assert count >= 0
    end

    test "count matches length of list_galls" do
      count = Species.count_galls()
      galls = Species.list_galls()
      assert count == length(galls)
    end
  end

  describe "get_species/1" do
    test "returns nil for non-existent ID" do
      assert nil == Species.get_species(999_999_999)
    end

    test "returns species for valid ID" do
      galls = Species.list_galls()

      if length(galls) > 0 do
        species = Species.get_species(hd(galls).id)
        assert species != nil
        assert species.id == hd(galls).id
      end
    end
  end

  describe "get_species!/1" do
    test "raises for non-existent ID" do
      assert_raise Ecto.NoResultsError, fn ->
        Species.get_species!(999_999_999)
      end
    end
  end

  describe "get_gall_by_id/1" do
    test "returns nil for non-existent gall" do
      assert nil == Species.get_gall_by_id(999_999_999)
    end

    test "returns gall with expected fields for valid ID" do
      galls = Species.list_galls()

      if length(galls) > 0 do
        gall = Species.get_gall_by_id(hd(galls).id)
        assert gall != nil
        assert Map.has_key?(gall, :id)
        assert Map.has_key?(gall, :name)
        assert Map.has_key?(gall, :gall_id)
        assert Map.has_key?(gall, :detachable)
        assert Map.has_key?(gall, :undescribed)
      end
    end
  end

  describe "get_gall_by_name/1" do
    test "returns nil for non-existent name" do
      assert nil == Species.get_gall_by_name("Nonexistent species name xyz")
    end

    test "returns gall for valid name" do
      galls = Species.list_galls()

      if length(galls) > 0 do
        gall = Species.get_gall_by_name(hd(galls).name)
        assert gall != nil
        assert gall.name == hd(galls).name
      end
    end
  end

  describe "get_images_for_species/1" do
    test "returns empty list for non-existent species" do
      images = Species.get_images_for_species(999_999_999)
      assert images == []
    end

    test "returns images with expected fields" do
      galls = Species.list_galls()

      if length(galls) > 0 do
        images = Species.get_images_for_species(hd(galls).id)
        assert is_list(images)

        if length(images) > 0 do
          image = hd(images)
          assert Map.has_key?(image, :id)
          assert Map.has_key?(image, :path)
          assert Map.has_key?(image, :default)
        end
      end
    end
  end

  describe "get_aliases_for_species/1" do
    test "returns empty list for non-existent species" do
      aliases = Species.get_aliases_for_species(999_999_999)
      assert aliases == []
    end

    test "returns aliases with expected fields" do
      galls = Species.list_galls()

      # Find a gall with aliases
      gall_with_alias =
        Enum.find(galls, fn g ->
          length(Species.get_aliases_for_species(g.id)) > 0
        end)

      if gall_with_alias do
        aliases = Species.get_aliases_for_species(gall_with_alias.id)
        alias_entry = hd(aliases)
        assert Map.has_key?(alias_entry, :id)
        assert Map.has_key?(alias_entry, :name)
        assert Map.has_key?(alias_entry, :type)
      end
    end
  end

  describe "random_gall/0" do
    test "returns a gall with image or nil" do
      result = Species.random_gall()

      if result != nil do
        assert Map.has_key?(result, :id)
        assert Map.has_key?(result, :name)
        assert Map.has_key?(result, :image_url)
        assert String.contains?(result.image_url, "http")
      end
    end
  end

  describe "get_default_gall_images/0" do
    test "returns a list of image maps" do
      images = Species.get_default_gall_images()
      assert is_list(images)

      if length(images) > 0 do
        image = hd(images)
        assert Map.has_key?(image, :species_id)
        assert Map.has_key?(image, :path)
      end
    end
  end

  describe "list_abundances/0" do
    test "returns a list of abundances" do
      abundances = Species.list_abundances()
      assert is_list(abundances)
    end
  end

  describe "get_abundance/1" do
    test "returns nil for non-existent abundance" do
      assert nil == Species.get_abundance(999_999_999)
    end
  end
end
