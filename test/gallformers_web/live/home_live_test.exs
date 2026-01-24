defmodule GallformersWeb.HomeLiveTest do
  use GallformersWeb.ConnCase
  import Phoenix.LiveViewTest

  describe "Home page" do
    test "renders welcome message", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Welcome to Gallformers"
      assert html =~ "Plant galls are abnormal growths"
      assert html =~ "Things You Can Do"
      assert html =~ "Help Us Out"
    end

    test "displays random gall section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      # Should show the Random Gall card (may show "Loading..." before connected)
      assert html =~ "Random Gall"
    end

    test "contains navigation links", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ ~s(href="/id")
      assert html =~ ~s(href="/refindex")
      assert html =~ ~s(href="/explore")
    end

    test "contains external links", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "patreon.com/gallformers"
      assert html =~ "github.com/jeffdc/gallformers"
    end
  end
end
