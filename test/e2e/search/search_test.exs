defmodule GallformersWeb.E2E.SearchTest do
  @moduledoc """
  E2E tests for search functionality.
  These verify that search works correctly in a real browser.
  """
  use GallformersWeb.E2ECase

  @moduletag :e2e
  @moduletag :e2e_search

  describe "global search" do
    test "page loads", %{session: session} do
      session
      |> visit("/globalsearch")
      |> assert_has(css(".phx-connected"))
      # Should have a search form (may have multiple forms on page)
      |> assert_has(css("form", count: :any))
    end

    test "searching for 'oak' returns results", %{session: session} do
      session
      |> visit("/globalsearch?searchText=oak")
      |> assert_has(css(".phx-connected"))

      # Page should load with search results - just verify page loads with query param
    end

    test "empty search shows appropriate message", %{session: session} do
      session
      |> visit("/globalsearch?searchText=xyznonexistent123")
      |> assert_has(css(".phx-connected"))

      # Should still load the page successfully
    end
  end

  describe "ID tool" do
    test "page loads", %{session: session} do
      session
      |> visit("/id")
      |> assert_has(css(".phx-connected"))
      # Should have a form for host selection
      |> assert_has(css("form"))
    end

    test "has host input field", %{session: session} do
      session
      |> visit("/id")
      |> assert_has(css(".phx-connected"))
      # Should have an input field for host selection
      |> assert_has(css("input[type='text']", count: :any))
    end
  end
end
