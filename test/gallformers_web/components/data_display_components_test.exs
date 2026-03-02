defmodule GallformersWeb.DataDisplayComponentsTest do
  @moduledoc """
  Tests for data display components.
  """
  use GallformersWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias GallformersWeb.DataDisplayComponents

  describe "taxonomy_breadcrumb" do
    test "renders family and genus with no intermediates" do
      html =
        render_component(&DataDisplayComponents.taxonomy_breadcrumb/1,
          family: %{id: 1, name: "Cynipidae"},
          genus: %{id: 2, name: "Andricus", description: nil},
          intermediates: []
        )

      assert html =~ "Cynipidae"
      assert html =~ "Andricus"
      refute html =~ "Subfamily"
    end

    test "renders one intermediate between family and genus" do
      html =
        render_component(&DataDisplayComponents.taxonomy_breadcrumb/1,
          family: %{id: 1, name: "Cynipidae"},
          intermediates: [%{id: 2, name: "Cynipinae", rank: "Subfamily"}],
          genus: %{id: 3, name: "Andricus", description: nil}
        )

      assert html =~ "Cynipidae"
      assert html =~ "Subfamily:"
      assert html =~ "Cynipinae"
      assert html =~ "Andricus"
    end

    test "renders two intermediates between family and genus" do
      html =
        render_component(&DataDisplayComponents.taxonomy_breadcrumb/1,
          family: %{id: 1, name: "Cynipidae"},
          intermediates: [
            %{id: 2, name: "Cynipinae", rank: "Subfamily"},
            %{id: 3, name: "Cynipini", rank: "Tribe"}
          ],
          genus: %{id: 4, name: "Andricus", description: nil}
        )

      assert html =~ "Cynipidae"
      assert html =~ "Subfamily:"
      assert html =~ "Cynipinae"
      assert html =~ "Tribe:"
      assert html =~ "Cynipini"
      assert html =~ "Andricus"
    end

    test "intermediate links point to /taxonomy/:id" do
      html =
        render_component(&DataDisplayComponents.taxonomy_breadcrumb/1,
          family: %{id: 1, name: "Cynipidae"},
          intermediates: [%{id: 42, name: "Cynipinae", rank: "Subfamily"}],
          genus: %{id: 3, name: "Andricus", description: nil}
        )

      assert html =~ "/taxonomy/42"
    end

    test "renders identically to before when intermediates is nil or empty" do
      with_nil =
        render_component(&DataDisplayComponents.taxonomy_breadcrumb/1,
          family: %{id: 1, name: "Cynipidae"},
          genus: %{id: 2, name: "Andricus", description: nil},
          intermediates: nil
        )

      with_empty =
        render_component(&DataDisplayComponents.taxonomy_breadcrumb/1,
          family: %{id: 1, name: "Cynipidae"},
          genus: %{id: 2, name: "Andricus", description: nil},
          intermediates: []
        )

      # Both should contain family and genus, no intermediate-specific content
      assert with_nil =~ "Cynipidae"
      assert with_nil =~ "Andricus"
      assert with_empty =~ "Cynipidae"
      assert with_empty =~ "Andricus"
      refute with_nil =~ "Subfamily"
      refute with_empty =~ "Subfamily"
    end
  end
end
