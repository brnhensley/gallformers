defmodule GallformersWeb.IntermediateLiveTest do
  @moduledoc """
  Tests for the public intermediate taxonomy browse page.
  """
  use GallformersWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  describe "IntermediateLive" do
    test "renders intermediate page with rank and name", %{conn: conn} do
      # Cynipinae is a Subfamily intermediate (id=31) in test seeds
      {:ok, _view, html} = live(conn, "/taxonomy/31")

      assert html =~ "Subfamily"
      assert html =~ "Cynipinae"
    end

    test "shows breadcrumb with parent family", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/taxonomy/31")

      assert html =~ "Cynipidae"
      assert html =~ "/family/30"
    end

    test "shows children with species counts", %{conn: conn} do
      # Cynipini (tribe, id=32) is a child of Cynipinae (id=31)
      {:ok, _view, html} = live(conn, "/taxonomy/31")

      assert html =~ "Cynipini"
    end

    test "shows genera as children of tribe", %{conn: conn} do
      # Cynipini (id=32) has Andricus and Cynips as children
      {:ok, _view, html} = live(conn, "/taxonomy/32")

      assert html =~ "Andricus"
      assert html =~ "Cynips"
    end

    test "returns not found for non-intermediate types", %{conn: conn} do
      # Cynipidae (id=30) is a family, not an intermediate
      {:ok, _view, html} = live(conn, "/taxonomy/30")

      assert html =~ "not found" || html =~ "Not Found"
    end

    test "returns not found for invalid ID", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/taxonomy/999999")

      assert html =~ "not found" || html =~ "Not Found"
    end
  end
end
