defmodule GallformersWeb.TaxonomyURLTest do
  use ExUnit.Case, async: true

  alias GallformersWeb.TaxonomyURL

  describe "public_path/1" do
    test "family" do
      assert TaxonomyURL.public_path(%{type: "family", name: "Cynipidae"}) == "/family/Cynipidae"
    end

    test "genus" do
      assert TaxonomyURL.public_path(%{type: "genus", name: "Andricus"}) == "/genus/Andricus"
    end

    test "section" do
      assert TaxonomyURL.public_path(%{type: "section", name: "Quercus"}) == "/section/Quercus"
    end

    test "intermediate with rank" do
      assert TaxonomyURL.public_path(%{
               type: "intermediate",
               rank: "Subfamily",
               name: "Cynipinae"
             }) ==
               "/subfamily/Cynipinae"
    end

    test "intermediate with nil rank returns nil" do
      assert TaxonomyURL.public_path(%{type: "intermediate", rank: nil, name: "Cynipinae"}) == nil
    end

    test "intermediate with empty rank returns nil" do
      assert TaxonomyURL.public_path(%{type: "intermediate", rank: "", name: "Cynipinae"}) == nil
    end

    test "unknown type returns nil" do
      assert TaxonomyURL.public_path(%{type: "unknown", name: "Foo"}) == nil
    end

    test "works with structs (any map with type/name)" do
      assert TaxonomyURL.public_path(%{type: "family", name: "Eriophyidae", extra: true}) ==
               "/family/Eriophyidae"
    end

    test "encodes names with spaces and special characters" do
      assert TaxonomyURL.public_path(%{type: "family", name: "Santalaceae (gall)"}) ==
               "/family/Santalaceae%20(gall)"

      assert TaxonomyURL.public_path(%{type: "genus", name: "Unknown (Cynipidae)"}) ==
               "/genus/Unknown%20(Cynipidae)"
    end
  end

  describe "numeric?/1" do
    test "pure digits" do
      assert TaxonomyURL.numeric?("123")
      assert TaxonomyURL.numeric?("0")
    end

    test "non-numeric strings" do
      refute TaxonomyURL.numeric?("Cynipidae")
      refute TaxonomyURL.numeric?("12a")
      refute TaxonomyURL.numeric?("")
    end

    test "strings with spaces or symbols" do
      refute TaxonomyURL.numeric?("12 34")
      refute TaxonomyURL.numeric?("-1")
    end
  end
end
