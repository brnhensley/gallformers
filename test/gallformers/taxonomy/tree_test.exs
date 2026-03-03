defmodule Gallformers.Taxonomy.TreeTest do
  use Gallformers.DataCase, async: false

  alias Gallformers.Repo
  alias Gallformers.Species.Species
  alias Gallformers.Taxonomy
  alias Gallformers.Taxonomy.Tree

  describe "update_taxonomy/2 type safety" do
    setup do
      # Create a family with a genus that has linked species
      {:ok, family} =
        Tree.create_taxonomy(%{name: "TypeGuardFamily", type: "family", description: "Wasp"})

      {:ok, genus} =
        Tree.create_taxonomy(%{name: "TypeGuardGenus", type: "genus", parent_id: family.id})

      {:ok, species} =
        Repo.insert(%Species{
          name: "TypeGuardGenus testspecies",
          taxoncode: "gall",
          datacomplete: false
        })

      Taxonomy.link_species_to_taxonomy(species.id, genus.id)

      {:ok, family: family, genus: genus, species: species}
    end

    test "does not rename species when type changes from genus", %{genus: genus} do
      # If type changes away from genus, even with a name change, species should NOT be renamed
      # This should be blocked entirely because species are linked
      result = Tree.update_taxonomy(genus, %{"type" => "section", "name" => "NewName"})

      assert {:error, changeset} = result
      assert changeset.errors[:type]
    end

    test "blocks type change when species are linked", %{genus: genus} do
      result = Tree.update_taxonomy(genus, %{"type" => "section"})

      assert {:error, changeset} = result
      {msg, _} = changeset.errors[:type]
      assert msg =~ "cannot change type"
    end

    test "allows type change when no species are linked" do
      {:ok, family} =
        Tree.create_taxonomy(%{name: "NoSpeciesFamily", type: "family", description: "Plant"})

      {:ok, genus} =
        Tree.create_taxonomy(%{name: "EmptyGenus", type: "genus", parent_id: family.id})

      # No species linked — type change should work
      # We just check it doesn't fail with the "cannot change type" error
      result = Tree.update_taxonomy(genus, %{"type" => "section", "parent_id" => genus.parent_id})

      case result do
        {:error, changeset} -> refute changeset.errors[:type]
        {:ok, _} -> :ok
      end
    end

    test "genuine genus rename still works and renames species", %{genus: genus, species: species} do
      # A genuine rename (type stays genus, name changes) should still rename species
      {:ok, updated} = Tree.update_taxonomy(genus, %{"name" => "RenamedGenus"})

      assert updated.name == "RenamedGenus"

      # Species should have been renamed
      updated_species = Repo.get!(Species, species.id)
      assert updated_species.name =~ "RenamedGenus"
    end
  end
end
