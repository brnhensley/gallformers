defmodule GallformersWeb.FamilyLiveTest do
  @moduledoc """
  Tests for the public family browse page with intermediate support.
  """
  use GallformersWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  describe "FamilyLive with name-based URLs" do
    test "renders family page by name", %{conn: conn} do
      # Cynipidae (id=30) should be accessible by name
      {:ok, _view, html} = live(conn, "/family/Cynipidae")

      assert html =~ "Cynipidae"
      # Intermediate should appear in tree with rank label
      assert html =~ "Cynipinae"
      assert html =~ "Subfamily"
    end

    test "renders genera nested under intermediates after expand", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/family/Cynipidae")

      # Expand all nodes to reveal nested genera
      html = render_click(view, "expand_all")

      # Andricus and Cynips are nested under Cynipini (tribe) under Cynipinae (subfamily)
      assert html =~ "Andricus"
      assert html =~ "Cynips"
      assert html =~ "Cynipini"
    end

    test "tree node URLs use names not IDs", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/family/Cynipidae")

      html = render_click(view, "expand_all")

      # Intermediate URLs should use rank-based paths with names
      assert html =~ "/subfamily/Cynipinae"
      refute html =~ "/taxonomy/31"

      # Genus URLs should use names
      assert html =~ "/genus/Andricus"
      refute html =~ "/genus/33"
    end

    test "returns error for nonexistent family name", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/family/Nonexistent")

      assert html =~ "not found" or html =~ "Not Found"
    end
  end
end
