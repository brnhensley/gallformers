defmodule Gallformers.Wcvp.WcvpDistributionTest do
  use ExUnit.Case, async: true

  alias Gallformers.Wcvp.WcvpDistribution

  describe "struct" do
    test "creates with core fields" do
      dist = %WcvpDistribution{
        plant_locality_id: "1",
        plant_name_id: "100",
        area_code_l3: "ALB",
        introduced: "0",
        extinct: "0",
        location_doubtful: "0"
      }

      assert dist.plant_locality_id == "1"
      assert dist.plant_name_id == "100"
      assert dist.area_code_l3 == "ALB"
      assert dist.introduced == "0"
    end

    test "has all 11 columns from Kew CSV" do
      expected_fields =
        ~w[
          plant_locality_id plant_name_id continent_code_l1 continent
          region_code_l2 region area_code_l3 area introduced extinct
          location_doubtful
        ]a

      schema_fields = WcvpDistribution.__schema__(:fields)

      for field <- expected_fields do
        assert field in schema_fields, "Missing field: #{field}"
      end

      assert length(schema_fields) == 11
    end

    test "primary key is plant_locality_id" do
      assert WcvpDistribution.__schema__(:primary_key) == [:plant_locality_id]
    end

    test "maps to wcvp_distributions table" do
      assert WcvpDistribution.__schema__(:source) == "wcvp_distributions"
    end
  end
end
