defmodule Gallformers.Taxonomy.ReclassificationTest do
  @moduledoc """
  Tests for reclassification and rename functions in Taxonomy.Reclassification.
  """
  use Gallformers.DataCase, async: true

  alias Gallformers.Repo
  alias Gallformers.Species
  alias Gallformers.Taxonomy
  alias Gallformers.Taxonomy.{Reclassification, SpeciesLink}

  describe "rename_species/3 collision detection" do
    setup do
      {:ok, species1} =
        Repo.insert(%Gallformers.Species.Species{
          name: "Testgenus alpha",
          taxoncode: "gall",
          datacomplete: false
        })

      {:ok, species2} =
        Repo.insert(%Gallformers.Species.Species{
          name: "Testgenus beta",
          taxoncode: "gall",
          datacomplete: false
        })

      {:ok, species1: species1, species2: species2}
    end

    test "returns {:error, :name_exists} when target name already exists", %{
      species1: species1,
      species2: species2
    } do
      assert {:error, :name_exists} =
               Reclassification.rename_species(species1.id, species2.name, false)

      # Verify species1 was not renamed
      unchanged = Species.get_species!(species1.id)
      assert unchanged.name == "Testgenus alpha"
    end

    test "succeeds when target name does not exist", %{species1: species1} do
      assert {:ok, updated} =
               Reclassification.rename_species(species1.id, "Testgenus gamma", true)

      assert updated.name == "Testgenus gamma"

      # Verify alias was created
      aliases = Species.get_aliases_for_species(species1.id)
      assert length(aliases) == 1
      assert hd(aliases).name == "Testgenus alpha"
    end

    test "no-ops when new name matches current name", %{species1: species1} do
      assert {:ok, returned} =
               Reclassification.rename_species(species1.id, "Testgenus alpha", true)

      assert returned.name == "Testgenus alpha"

      # No alias should be created for a no-op
      aliases = Species.get_aliases_for_species(species1.id)
      assert aliases == []
    end

    test "species is searchable after rename", %{species1: species1} do
      assert {:ok, _updated} =
               Reclassification.rename_species(species1.id, "Xyzuniquename testsearch", false)

      # Should be findable via search
      results = Species.search_species("xyzuniquename", 10)
      assert Enum.any?(results, &(&1.id == species1.id)) == true
    end
  end

  describe "rename_for_genus_change/4 collision detection" do
    setup do
      {:ok, species1} =
        Repo.insert(%Gallformers.Species.Species{
          name: "Oldgenus alpha",
          taxoncode: "gall",
          datacomplete: false
        })

      # Create a species that would collide after genus rename
      {:ok, colliding} =
        Repo.insert(%Gallformers.Species.Species{
          name: "Newgenus alpha",
          taxoncode: "gall",
          datacomplete: false
        })

      {:ok, species1: species1, colliding: colliding}
    end

    test "returns {:error, :name_exists} when computed name collides", %{species1: species1} do
      assert {:error, :name_exists} =
               Reclassification.rename_for_genus_change(species1, "Oldgenus", "Newgenus")

      # Verify species1 was not renamed
      unchanged = Species.get_species!(species1.id)
      assert unchanged.name == "Oldgenus alpha"
    end

    test "succeeds when computed name does not collide", %{species1: species1} do
      assert {:ok, updated} =
               Reclassification.rename_for_genus_change(species1, "Oldgenus", "Safenewgenus")

      assert updated.name == "Safenewgenus alpha"
    end
  end

  describe "reclassify_species/2 with new genus creation" do
    setup do
      {:ok, family} =
        Taxonomy.create_taxonomy(%{
          name: "ReclassifyTestFamily",
          type: "family",
          description: "Wasp"
        })

      {:ok, genus} =
        Taxonomy.create_taxonomy(%{
          name: "Reclassifytestgenus",
          type: "genus",
          parent_id: family.id
        })

      {:ok, species} =
        Repo.insert(%Gallformers.Species.Species{
          name: "Reclassifytestgenus alpha",
          taxoncode: "gall",
          datacomplete: false
        })

      SpeciesLink.link_species_to_taxonomy(species.id, genus.id)

      {:ok, family: family, genus: genus, species: species}
    end

    test "reclassify to existing genus (unchanged behavior)", ctx do
      {:ok, other_family} =
        Taxonomy.create_taxonomy(%{
          name: "OtherReclassifyFamily",
          type: "family",
          description: "Midge"
        })

      {:ok, other_genus} =
        Taxonomy.create_taxonomy(%{
          name: "Otherreclassifygenus",
          type: "genus",
          parent_id: other_family.id
        })

      params = %{
        genus_id: other_genus.id,
        new_name: "Otherreclassifygenus alpha",
        old_name: ctx.species.name,
        genus_changed?: true,
        name_changed?: true,
        add_alias?: true
      }

      assert {:ok, updated} = Reclassification.reclassify_species(ctx.species.id, params)
      assert updated.name == "Otherreclassifygenus alpha"
    end

    test "reclassify to new genus under existing family", ctx do
      params = %{
        genus_name: "Brandnewreclgenus",
        family_id: ctx.family.id,
        genus_is_new: true,
        new_name: "Brandnewreclgenus alpha",
        old_name: ctx.species.name,
        genus_changed?: true,
        name_changed?: true,
        add_alias?: true
      }

      assert {:ok, updated} = Reclassification.reclassify_species(ctx.species.id, params)
      assert updated.name == "Brandnewreclgenus alpha"

      # Verify genus was created
      assert Taxonomy.get_taxonomy_by_name("Brandnewreclgenus", "genus") != nil
    end

    test "reclassify to new genus under new family", ctx do
      params = %{
        genus_name: "Freshreclgenus",
        family_is_new: true,
        family_name: "FreshReclFamily",
        family_type: "Fly",
        genus_is_new: true,
        new_name: "Freshreclgenus alpha",
        old_name: ctx.species.name,
        genus_changed?: true,
        name_changed?: true,
        add_alias?: true
      }

      assert {:ok, updated} = Reclassification.reclassify_species(ctx.species.id, params)
      assert updated.name == "Freshreclgenus alpha"

      # Verify family and genus were created
      assert Taxonomy.get_taxonomy_by_name("FreshReclFamily", "family") != nil
      assert Taxonomy.get_taxonomy_by_name("Freshreclgenus", "genus") != nil
    end

    test "alias created for old name when requested", ctx do
      {:ok, other_family} =
        Taxonomy.create_taxonomy(%{
          name: "AliasReclassifyFamily",
          type: "family",
          description: "Midge"
        })

      {:ok, other_genus} =
        Taxonomy.create_taxonomy(%{
          name: "Aliasreclassifygenus",
          type: "genus",
          parent_id: other_family.id
        })

      params = %{
        genus_id: other_genus.id,
        new_name: "Aliasreclassifygenus alpha",
        old_name: ctx.species.name,
        genus_changed?: true,
        name_changed?: true,
        add_alias?: true
      }

      assert {:ok, _updated} = Reclassification.reclassify_species(ctx.species.id, params)

      aliases = Species.get_aliases_for_species(ctx.species.id)
      assert Enum.any?(aliases, &(&1.name == "Reclassifytestgenus alpha")) == true
    end
  end
end
