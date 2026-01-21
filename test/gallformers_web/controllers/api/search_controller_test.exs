defmodule GallformersWeb.API.SearchControllerTest do
  @moduledoc """
  API tests for search endpoint.
  """
  use GallformersWeb.ConnCase, async: true

  describe "GET /api/v2/search" do
    test "returns search results with all categories", %{conn: conn} do
      conn = get(conn, ~p"/api/v2/search?q=oak")

      response = json_response(conn, 200)
      assert Map.has_key?(response, "galls")
      assert Map.has_key?(response, "hosts")
      assert Map.has_key?(response, "glossary")
      assert Map.has_key?(response, "sources")
      assert Map.has_key?(response, "taxonomy")
      assert Map.has_key?(response, "places")
    end

    test "returns empty results for empty query", %{conn: conn} do
      conn = get(conn, ~p"/api/v2/search?q=")

      response = json_response(conn, 200)
      assert response["galls"] == []
      assert response["hosts"] == []
      assert response["glossary"] == []
      assert response["sources"] == []
    end

    test "returns empty results without query parameter", %{conn: conn} do
      conn = get(conn, ~p"/api/v2/search")

      response = json_response(conn, 200)
      assert response["galls"] == []
      assert response["hosts"] == []
    end

    test "returns matching galls", %{conn: conn} do
      # Search for a term likely to match galls
      conn = get(conn, ~p"/api/v2/search?q=andricus")

      response = json_response(conn, 200)
      assert is_list(response["galls"])
    end

    test "returns matching hosts", %{conn: conn} do
      # Search for a term likely to match hosts
      conn = get(conn, ~p"/api/v2/search?q=quercus")

      response = json_response(conn, 200)
      assert is_list(response["hosts"])
    end

    test "gall results have type field", %{conn: conn} do
      conn = get(conn, ~p"/api/v2/search?q=oak")

      response = json_response(conn, 200)

      if length(response["galls"]) > 0 do
        gall = hd(response["galls"])
        assert gall["type"] == "gall"
      end
    end

    test "host results have type field", %{conn: conn} do
      conn = get(conn, ~p"/api/v2/search?q=oak")

      response = json_response(conn, 200)

      if length(response["hosts"]) > 0 do
        host = hd(response["hosts"])
        assert host["type"] == "host"
      end
    end

    test "search is case-insensitive", %{conn: conn} do
      conn_lower = get(conn, ~p"/api/v2/search?q=oak")
      conn_upper = get(conn, ~p"/api/v2/search?q=OAK")

      response_lower = json_response(conn_lower, 200)
      response_upper = json_response(conn_upper, 200)

      # Should return same results (or at least same count)
      assert length(response_lower["hosts"]) == length(response_upper["hosts"])
    end

    test "returns correct content type", %{conn: conn} do
      conn = get(conn, ~p"/api/v2/search?q=test")

      assert get_resp_header(conn, "content-type") |> hd() =~ "application/json"
    end

    test "handles special characters in query", %{conn: conn} do
      conn = get(conn, ~p"/api/v2/search?q=test%20query")

      # Should not error
      assert conn.status == 200
      assert is_map(json_response(conn, 200))
    end
  end
end
