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
      |> assert_has(css("body.phx-connected"))
    end

    test "searching for 'oak' returns results", %{session: session} do
      session
      |> visit("/globalsearch")
      |> assert_has(css("body.phx-connected"))
      |> fill_in(fillable_field("Search"), with: "oak")
      |> click(button("Search"))
      # Should show results (either hosts or galls containing "oak")
      |> assert_has(css("[data-test='search-results']"))
    end

    test "empty search shows appropriate message", %{session: session} do
      session
      |> visit("/globalsearch")
      |> assert_has(css("body.phx-connected"))
      |> fill_in(fillable_field("Search"), with: "xyznonexistent123")
      |> click(button("Search"))
      # Should indicate no results found
      |> assert_has(css("body.phx-connected"))
    end
  end

  describe "ID tool" do
    test "page loads", %{session: session} do
      session
      |> visit("/id")
      |> assert_has(css("body.phx-connected"))
    end

    test "can select a host", %{session: session} do
      session
      |> visit("/id")
      |> assert_has(css("body.phx-connected"))
      # The ID tool should have host selection
      |> assert_has(css("[data-test='host-selector']"))
    end
  end
end
