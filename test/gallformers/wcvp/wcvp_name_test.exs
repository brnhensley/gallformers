defmodule Gallformers.Wcvp.WcvpNameTest do
  use ExUnit.Case, async: true

  alias Gallformers.Wcvp.WcvpName

  describe "struct" do
    test "creates with core fields" do
      name = %WcvpName{
        plant_name_id: "100",
        taxon_name: "Quercus alba",
        family: "Fagaceae",
        genus: "Quercus",
        species: "alba",
        taxon_authors: "L.",
        powo_id: "urn:lsid:ipni.org:names:295763-1",
        taxon_status: "Accepted"
      }

      assert name.plant_name_id == "100"
      assert name.taxon_name == "Quercus alba"
      assert name.family == "Fagaceae"
      assert name.taxon_status == "Accepted"
    end

    test "virtual distribution fields default to empty lists" do
      name = %WcvpName{}
      assert name.native_distribution == []
      assert name.introduced_distribution == []
    end

    test "has all 31 persisted columns from Kew CSV" do
      expected_fields =
        ~w[
          plant_name_id ipni_id taxon_rank taxon_status family genus_hybrid genus
          species_hybrid species infraspecific_rank infraspecies parenthetical_author
          primary_author publication_author place_of_publication volume_and_page
          first_published nomenclatural_remarks geographic_area lifeform_description
          climate_description taxon_name taxon_authors accepted_plant_name_id
          basionym_plant_name_id replaced_synonym_author homotypic_synonym
          parent_plant_name_id powo_id hybrid_formula reviewed
        ]a

      schema_fields =
        WcvpName.__schema__(:fields)

      for field <- expected_fields do
        assert field in schema_fields, "Missing field: #{field}"
      end

      assert length(schema_fields) == 31
    end

    test "has virtual distribution fields" do
      virtual_fields = WcvpName.__schema__(:virtual_fields)
      assert :native_distribution in virtual_fields
      assert :introduced_distribution in virtual_fields
    end

    test "primary key is plant_name_id" do
      assert WcvpName.__schema__(:primary_key) == [:plant_name_id]
    end

    test "maps to wcvp_names table" do
      assert WcvpName.__schema__(:source) == "wcvp_names"
    end
  end
end
