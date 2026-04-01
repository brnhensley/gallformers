defmodule Gallformers.Taxonomy.SpeciesLinkTest do
  @moduledoc """
  Tests for genus/family resolution in Taxonomy.SpeciesLink.
  """
  use Gallformers.DataCase, async: true

  import Ecto.Query
  alias Gallformers.Taxonomy
  alias Gallformers.Taxonomy.{Genus, Lineage, SpeciesLink}

  describe "place_species_in_tree/3" do
    setup do
      {:ok, family} =
        Taxonomy.create_taxonomy(%{
          name: "PlaceTreeFamily",
          type: "family",
          description: "Wasp"
        })

      {:ok, genus} =
        Taxonomy.create_taxonomy(%{
          name: "Placetreegenus",
          type: "genus",
          parent_id: family.id
        })

      {:ok, species} =
        Repo.insert(%Gallformers.Species.Species{
          name: "Placetreegenus alpha",
          taxoncode: "gall",
          datacomplete: false
        })

      {:ok, family: family, genus: genus, species: species}
    end

    test "links species to existing genus", %{genus: genus, species: species} do
      lineage = %Lineage{genus: %Genus{id: genus.id, name: genus.name}}

      assert :ok = SpeciesLink.place_species_in_tree(species.id, lineage)

      taxonomy = Taxonomy.get_taxonomy_for_species(species.id)
      assert taxonomy.genus.id == genus.id
    end

    test "creates new genus and links species when genus.id is nil", %{
      family: family,
      species: species
    } do
      lineage = %Lineage{genus: %Genus{name: "Brandnewplacegenus"}}

      assert :ok = SpeciesLink.place_species_in_tree(species.id, lineage, parent_id: family.id)

      taxonomy = Taxonomy.get_taxonomy_for_species(species.id)
      assert taxonomy.genus.name == "Brandnewplacegenus"
      assert taxonomy.family.id == family.id
    end

    test "uses find_or_create for Unknown genus", %{family: family, species: species} do
      lineage = %Lineage{genus: %Genus{name: "Unknown"}}

      assert :ok = SpeciesLink.place_species_in_tree(species.id, lineage, parent_id: family.id)

      taxonomy = Taxonomy.get_taxonomy_for_species(species.id)
      assert taxonomy.genus.name =~ "Unknown"

      # Should reuse existing Unknown genus, not create a second one
      unknown_count =
        Repo.one(
          from(t in Taxonomy.Taxonomy,
            where: t.is_placeholder == true and t.type == "genus" and t.parent_id == ^family.id,
            select: count()
          )
        )

      assert unknown_count == 1
    end

    test "links section when section_id provided", %{genus: genus, species: species} do
      {:ok, section} =
        Taxonomy.create_taxonomy(%{
          name: "PlaceTreeSection",
          type: "section",
          parent_id: genus.id
        })

      lineage = %Lineage{genus: %Genus{id: genus.id, name: genus.name}}

      assert :ok =
               SpeciesLink.place_species_in_tree(species.id, lineage, section_id: section.id)

      taxonomy = Taxonomy.get_taxonomy_for_species(species.id)
      assert taxonomy.genus.id == genus.id
      assert taxonomy.section != nil
      assert taxonomy.section.id == section.id
    end

    test "raises when genus is new but no parent_id", %{species: species} do
      lineage = %Lineage{genus: %Genus{name: "Orphangenus"}}

      assert_raise KeyError, fn ->
        SpeciesLink.place_species_in_tree(species.id, lineage)
      end
    end
  end

  describe "lookup_taxonomy_for_new_species/1" do
    setup do
      {:ok, family} =
        Taxonomy.create_taxonomy(%{
          name: "LookupTestFamily",
          type: "family",
          description: "Wasp"
        })

      {:ok, genus} =
        Taxonomy.create_taxonomy(%{
          name: "Lookuptestgenus",
          type: "genus",
          parent_id: family.id
        })

      {:ok, family: family, genus: genus}
    end

    test "returns {:ok, lineage} when genus exists in one family", ctx do
      assert {:ok, %Lineage{} = lineage} =
               SpeciesLink.lookup_taxonomy_for_new_species("Lookuptestgenus something")

      assert lineage.genus.id == ctx.genus.id
      assert lineage.genus.name == "Lookuptestgenus"
      assert lineage.family.id == ctx.family.id
    end

    test "returns {:new_genus, lineage} when genus does not exist" do
      assert {:new_genus, %Lineage{} = lineage} =
               SpeciesLink.lookup_taxonomy_for_new_species("Brandnewgenus something")

      assert lineage.genus.name == "Brandnewgenus"
      assert lineage.genus.id == nil
    end

    test "returns {:ambiguous, genus_name, families} when genus exists in multiple families" do
      {:ok, family2} =
        Taxonomy.create_taxonomy(%{
          name: "LookupTestFamily2",
          type: "family",
          description: "Plant"
        })

      {:ok, _genus2} =
        Taxonomy.create_taxonomy(%{
          name: "Ambiguousresgenus",
          type: "genus",
          parent_id: family2.id
        })

      {:ok, family3} =
        Taxonomy.create_taxonomy(%{
          name: "LookupTestFamily3",
          type: "family",
          description: "Midge"
        })

      {:ok, _genus3} =
        Taxonomy.create_taxonomy(%{
          name: "Ambiguousresgenus",
          type: "genus",
          parent_id: family3.id
        })

      assert {:ambiguous, "Ambiguousresgenus", families} =
               SpeciesLink.lookup_taxonomy_for_new_species("Ambiguousresgenus something")

      assert length(families) == 2
    end

    test "returns nil for empty or unparseable name" do
      assert SpeciesLink.lookup_taxonomy_for_new_species("") == nil
      assert SpeciesLink.lookup_taxonomy_for_new_species(nil) == nil
    end

    test "returns {:genus_reference, genus_name, genus_id} for 'spp.' pattern", ctx do
      assert {:genus_reference, "Lookuptestgenus", genus_id} =
               SpeciesLink.lookup_taxonomy_for_new_species("Lookuptestgenus spp.")

      assert genus_id == ctx.genus.id
    end

    test "returns {:genus_reference, genus_name, genus_id} for 'sp.' pattern", ctx do
      assert {:genus_reference, "Lookuptestgenus", genus_id} =
               SpeciesLink.lookup_taxonomy_for_new_species("Lookuptestgenus sp.")

      assert genus_id == ctx.genus.id
    end

    test "returns {:genus_reference, genus_name, nil} when genus doesn't exist" do
      assert {:genus_reference, "Nonexistentgenus", nil} =
               SpeciesLink.lookup_taxonomy_for_new_species("Nonexistentgenus spp.")
    end
  end
end
