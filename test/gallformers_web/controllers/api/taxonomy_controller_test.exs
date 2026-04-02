defmodule GallformersWeb.API.TaxonomyControllerTest do
  @moduledoc """
  API tests for taxonomy endpoints.
  """
  use GallformersWeb.ConnCase

  alias Gallformers.Repo
  alias Gallformers.Taxonomy.Taxonomy

  describe "GET /api/v2/genera" do
    test "returns paginated list of genera", %{conn: conn} do
      conn = get(conn, ~p"/api/v2/genera")

      response = json_response(conn, 200)
      assert Map.has_key?(response, "data") == true
      assert Map.has_key?(response, "total") == true
      assert is_list(response["data"])
    end

    test "genera have expected fields", %{conn: conn} do
      conn = get(conn, ~p"/api/v2/genera?limit=5")

      response = json_response(conn, 200)

      if length(response["data"]) > 0 do
        genus = hd(response["data"])
        assert Map.has_key?(genus, "id") == true
        assert Map.has_key?(genus, "name") == true
        assert Map.has_key?(genus, "type") == true
        assert genus["type"] == "genus"
      end
    end

    test "respects limit parameter", %{conn: conn} do
      conn = get(conn, ~p"/api/v2/genera?limit=3")

      response = json_response(conn, 200)
      assert length(response["data"]) <= 3
    end

    test "respects offset parameter", %{conn: conn} do
      conn1 = get(conn, ~p"/api/v2/genera?limit=5&offset=0")
      conn2 = get(conn, ~p"/api/v2/genera?limit=5&offset=5")

      response1 = json_response(conn1, 200)
      response2 = json_response(conn2, 200)

      if length(response1["data"]) > 0 and length(response2["data"]) > 0 do
        ids1 = Enum.map(response1["data"], & &1["id"])
        ids2 = Enum.map(response2["data"], & &1["id"])
        assert MapSet.disjoint?(MapSet.new(ids1), MapSet.new(ids2)) == true
      end
    end

    test "search with q parameter", %{conn: conn} do
      conn = get(conn, ~p"/api/v2/genera?q=Quer")

      response = json_response(conn, 200)
      assert Map.has_key?(response, "data") == true
      assert is_list(response["data"])
    end

    test "only returns genus type entries", %{conn: conn} do
      conn = get(conn, ~p"/api/v2/genera")

      response = json_response(conn, 200)

      Enum.each(response["data"], fn entry ->
        assert entry["type"] == "genus"
      end)
    end
  end

  describe "GET /api/v2/families" do
    test "returns list of families", %{conn: conn} do
      conn = get(conn, ~p"/api/v2/families")

      response = json_response(conn, 200)
      assert is_list(response)
    end

    test "each family has children array with type discrimination", %{conn: conn} do
      # Cynipidae (id=30) has intermediate child Cynipinae (id=31)
      conn = get(conn, ~p"/api/v2/families")

      response = json_response(conn, 200)
      cynipidae = Enum.find(response, &(&1["name"] == "Cynipidae"))
      assert cynipidae, "Cynipidae should be in families list"

      assert is_list(cynipidae["children"]),
             "family should have 'children' key, not 'genera'"

      refute Map.has_key?(cynipidae, "genera"),
             "family should not have 'genera' key (replaced by 'children')"

      # Check that children have type field
      Enum.each(cynipidae["children"], fn child ->
        assert child["type"] in ["genus", "intermediate"],
               "child type should be 'genus' or 'intermediate', got: #{child["type"]}"
      end)
    end
  end

  describe "GET /api/v2/families/:id" do
    test "returns family with children including intermediates and genera", %{conn: conn} do
      # Cynipidae (id=30) has direct children:
      # - Cynipinae (id=31, intermediate, Subfamily)
      # - Unknown (id=35, placeholder genus — should be filtered)
      conn = get(conn, ~p"/api/v2/families/30")

      response = json_response(conn, 200)
      assert response["id"] == 30
      assert response["name"] == "Cynipidae"

      assert is_list(response["children"]),
             "family should have 'children' key, not 'genera'"

      refute Map.has_key?(response, "genera"),
             "family should not have 'genera' key (replaced by 'children')"

      # Should include the intermediate Cynipinae
      cynipinae = Enum.find(response["children"], &(&1["name"] == "Cynipinae"))
      assert cynipinae, "Cynipinae intermediate should be in children"
      assert cynipinae["type"] == "intermediate"
      assert cynipinae["rank"] == "Subfamily"

      # Should not include the empty Unknown placeholder
      unknown = Enum.find(response["children"], &(&1["name"] == "Unknown"))
      refute unknown, "empty Unknown placeholder should be filtered out"
    end

    test "returns 404 for non-existent family", %{conn: conn} do
      conn = get(conn, ~p"/api/v2/families/99999")
      assert json_response(conn, 404)["error"] != nil
    end
  end

  describe "GET /api/v2/intermediates/:id" do
    test "returns intermediate with rank, parent, and children", %{conn: conn} do
      # Cynipinae (id=31): Subfamily under Cynipidae (id=30)
      # Has child: Cynipini (id=32, Tribe)
      conn = get(conn, ~p"/api/v2/intermediates/31")

      response = json_response(conn, 200)
      assert response["id"] == 31
      assert response["name"] == "Cynipinae"
      assert response["type"] == "intermediate"
      assert response["rank"] == "Subfamily"

      # Parent should be Cynipidae
      assert response["parent"]["id"] == 30
      assert response["parent"]["name"] == "Cynipidae"
      assert response["parent"]["type"] == "family"

      # Children should include Cynipini
      assert is_list(response["children"])
      cynipini = Enum.find(response["children"], &(&1["name"] == "Cynipini"))
      assert cynipini, "Cynipini should be in children"
      assert cynipini["type"] == "intermediate"
      assert cynipini["rank"] == "Tribe"
    end

    test "returns intermediate with genus children", %{conn: conn} do
      # Cynipini (id=32): Tribe, has genus children Andricus (33) and Cynips (34)
      conn = get(conn, ~p"/api/v2/intermediates/32")

      response = json_response(conn, 200)
      assert response["id"] == 32
      assert response["name"] == "Cynipini"
      assert response["rank"] == "Tribe"

      # Parent should be Cynipinae
      assert response["parent"]["id"] == 31
      assert response["parent"]["name"] == "Cynipinae"

      children_names = Enum.map(response["children"], & &1["name"]) |> Enum.sort()
      assert "Andricus" in children_names
      assert "Cynips" in children_names

      # Genus children should have type "genus"
      andricus = Enum.find(response["children"], &(&1["name"] == "Andricus"))
      assert andricus["type"] == "genus"
    end

    test "returns 404 for a genus (non-intermediate)", %{conn: conn} do
      # Andricus (id=33) is a genus, not an intermediate
      conn = get(conn, ~p"/api/v2/intermediates/33")
      assert json_response(conn, 404)["error"] != nil
    end

    test "returns 404 for non-existent ID", %{conn: conn} do
      conn = get(conn, ~p"/api/v2/intermediates/99999")
      assert json_response(conn, 404)["error"] != nil
    end
  end

  describe "GET /api/v2/sections" do
    setup do
      # Create a section under GenusAlpha (id=10) for testing
      {:ok, section} =
        %Taxonomy{}
        |> Taxonomy.changeset(%{
          name: "sect. Quercus",
          type: "section",
          description: "Red oaks",
          parent_id: 10
        })
        |> Repo.insert()

      %{section: section}
    end

    test "returns list of sections with parent genus info", %{conn: conn, section: section} do
      conn = get(conn, ~p"/api/v2/sections")

      response = json_response(conn, 200)
      assert is_list(response)

      found = Enum.find(response, &(&1["id"] == section.id))
      assert found, "created section should appear in list"
      assert found["name"] == "sect. Quercus"
      assert found["type"] == "section"
      assert found["description"] == "Red oaks"
      assert found["genus_id"] == 10
      assert found["genus_name"] == "GenusAlpha"
    end
  end

  describe "GET /api/v2/genera/:id resolves family through intermediates" do
    test "returns ancestor family, not intermediate parent", %{conn: conn} do
      # Seed: Andricus (id=33) → Cynipini (tribe, 32) → Cynipinae (subfamily, 31) → Cynipidae (family, 30)
      conn = get(conn, ~p"/api/v2/genera/33")
      response = json_response(conn, 200)

      assert response["name"] == "Andricus"
      assert response["family"]["name"] == "Cynipidae"
      assert response["family"]["id"] == 30
    end
  end
end
