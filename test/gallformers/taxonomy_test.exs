defmodule Gallformers.TaxonomyTest do
  @moduledoc """
  Unit tests for the Taxonomy context.
  """
  use Gallformers.DataCase, async: false

  alias Gallformers.Repo
  alias Gallformers.Species.Alias
  alias Gallformers.Species.Species
  alias Gallformers.Taxonomy

  describe "update_taxonomy/2 genus rename" do
    setup do
      # Create a family
      {:ok, family} =
        Taxonomy.create_taxonomy(%{
          name: "TestFamilyRename",
          type: "family",
          description: "Test family for rename tests"
        })

      # Create a genus under the family
      {:ok, genus} =
        Taxonomy.create_taxonomy(%{
          name: "Testgenus",
          type: "genus",
          description: "Test genus",
          parent_id: family.id
        })

      # Create a species
      {:ok, species} =
        Repo.insert(%Species{
          name: "Testgenus alba",
          taxoncode: "gall",
          datacomplete: false
        })

      # Link species to genus
      Taxonomy.link_species_to_taxonomy(species.id, genus.id)

      {:ok, family: family, genus: genus, species: species}
    end

    test "renames species and creates synonyms when genus is renamed", %{
      genus: genus,
      species: species
    } do
      # Rename the genus
      {:ok, updated_genus} = Taxonomy.update_taxonomy(genus, %{"name" => "Newgenus"})

      assert updated_genus.name == "Newgenus"

      # Verify species name was updated
      updated_species = Repo.get!(Species, species.id)
      assert updated_species.name == "Newgenus alba"

      # Verify synonym was created
      aliases =
        from(a in Alias,
          join: as in "aliasspecies",
          on: as.alias_id == a.id,
          where: as.species_id == ^species.id,
          select: a
        )
        |> Repo.all()

      assert length(aliases) == 1
      [synonym] = aliases
      assert synonym.name == "Testgenus alba"
      assert synonym.type == "scientific"
      assert synonym.description == "Previous name"
    end

    test "handles multiple species under a genus", %{genus: genus} do
      # Create additional species
      {:ok, species2} =
        Repo.insert(%Species{
          name: "Testgenus rubra",
          taxoncode: "gall",
          datacomplete: false
        })

      {:ok, species3} =
        Repo.insert(%Species{
          name: "Testgenus nigra",
          taxoncode: "gall",
          datacomplete: false
        })

      Taxonomy.link_species_to_taxonomy(species2.id, genus.id)
      Taxonomy.link_species_to_taxonomy(species3.id, genus.id)

      # Rename the genus
      {:ok, _updated_genus} = Taxonomy.update_taxonomy(genus, %{"name" => "Anothergenus"})

      # All species should be renamed
      s2 = Repo.get!(Species, species2.id)
      s3 = Repo.get!(Species, species3.id)

      assert s2.name == "Anothergenus rubra"
      assert s3.name == "Anothergenus nigra"

      # Both should have synonyms
      for sp <- [species2.id, species3.id] do
        alias_count =
          from(as in "aliasspecies", where: as.species_id == ^sp, select: count())
          |> Repo.one()

        assert alias_count == 1
      end
    end

    test "does not sync species when updating non-name fields", %{genus: genus, species: species} do
      # Update description only
      {:ok, _updated_genus} = Taxonomy.update_taxonomy(genus, %{"description" => "Updated desc"})

      # Species name should be unchanged
      unchanged_species = Repo.get!(Species, species.id)
      assert unchanged_species.name == "Testgenus alba"

      # No synonyms should be created
      alias_count =
        from(as in "aliasspecies", where: as.species_id == ^species.id, select: count())
        |> Repo.one()

      assert alias_count == 0
    end

    test "does not sync species when name is unchanged", %{genus: genus, species: species} do
      # Update with same name
      {:ok, _updated_genus} = Taxonomy.update_taxonomy(genus, %{"name" => "Testgenus"})

      # Species name should be unchanged
      unchanged_species = Repo.get!(Species, species.id)
      assert unchanged_species.name == "Testgenus alba"

      # No synonyms should be created
      alias_count =
        from(as in "aliasspecies", where: as.species_id == ^species.id, select: count())
        |> Repo.one()

      assert alias_count == 0
    end

    test "does not affect family rename", %{family: family} do
      # Rename family should work normally without species sync
      {:ok, updated_family} = Taxonomy.update_taxonomy(family, %{"name" => "NewFamilyName"})
      assert updated_family.name == "NewFamilyName"
    end
  end
end
