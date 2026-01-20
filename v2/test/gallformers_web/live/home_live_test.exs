defmodule GallformersWeb.HomeLiveTest do
  use GallformersWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "Home page" do
    test "renders welcome message", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Welcome to Gallformers"
      assert html =~ "What the heck is a gall?!"
      assert html =~ "Stuff you can do"
      assert html =~ "Help Us Out"
    end

    test "displays random gall when available", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      # Should show either a random gall or the "no galls" message
      assert html =~ "random gall" or html =~ "No galls found"
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
