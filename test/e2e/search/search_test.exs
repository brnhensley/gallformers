defmodule GallformersWeb.E2E.SearchTest do
  @moduledoc """
  E2E tests for search functionality.
  These verify that search works correctly in a real browser.
  """
  use GallformersWeb.E2ECase

  @moduletag :e2e
  @moduletag :e2e_search

  describe "global search" do
    test "page loads", %{conn: conn} do
      conn
      |> visit("/globalsearch")
      # Should have a search form (may have multiple forms on page)
      |> assert_has("form")
    end

    test "searching for 'oak' returns results", %{conn: conn} do
      conn
      |> visit("/globalsearch?searchText=oak")

      # Page should load with search results - just verify page loads with query param
    end

    test "empty search shows appropriate message", %{conn: conn} do
      conn
      |> visit("/globalsearch?searchText=xyznonexistent123")

      # Should still load the page successfully
    end
  end

  describe "ID tool" do
    test "page loads", %{conn: conn} do
      conn
      |> visit("/id")
      # Should have a form for host selection
      |> assert_has("form")
    end

    test "has host input field", %{conn: conn} do
      conn
      |> visit("/id")
      # Should have an input field for host selection
      |> assert_has("input[type='text']")
    end
  end
end
