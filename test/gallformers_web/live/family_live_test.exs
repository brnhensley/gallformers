defmodule GallformersWeb.FamilyLiveTest do
  @moduledoc """
  Tests for the public family browse page with intermediate support.
  """
  use GallformersWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  describe "FamilyLive with intermediates" do
    test "renders family page with intermediate children", %{conn: conn} do
      # Cynipidae (id=30) has Cynipinae (subfamily intermediate) as a child
      {:ok, _view, html} = live(conn, "/family/30")

      assert html =~ "Cynipidae"
      # Intermediate should appear in tree with rank label
      assert html =~ "Cynipinae"
      assert html =~ "Subfamily"
    end

    test "renders genera nested under intermediates after expand", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/family/30")

      # Expand all nodes to reveal nested genera
      html = render_click(view, "expand_all")

      # Andricus and Cynips are nested under Cynipini (tribe) under Cynipinae (subfamily)
      assert html =~ "Andricus"
      assert html =~ "Cynips"
      assert html =~ "Cynipini"
    end
  end
end
