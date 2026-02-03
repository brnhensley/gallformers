defmodule GallformersWeb.TreeComponentsTest do
  use GallformersWeb.ConnCase
  import Phoenix.LiveViewTest

  defmodule TestLive do
    use Phoenix.LiveView

    def render(assigns) do
      ~H"""
      <GallformersWeb.TreeComponents.tree_browser
        id={@id}
        nodes={@nodes}
        expanded={@expanded}
        search_query={@search_query}
        show_search={@show_search}
        show_controls={@show_controls}
        on_toggle={@on_toggle}
        on_expand_all={@on_expand_all}
        on_collapse_all={@on_collapse_all}
        on_search={@on_search}
      />
      """
    end

    def mount(_params, _session, socket) do
      {:ok,
       assign(socket,
         id: "test-tree",
         nodes: [],
         expanded: MapSet.new(),
         search_query: "",
         show_search: true,
         show_controls: true,
         on_toggle: "toggle_node",
         on_expand_all: "expand_all",
         on_collapse_all: "collapse_all",
         on_search: "search"
       )}
    end
  end

  describe "tree_browser/1" do
    test "renders empty tree message", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, TestLive)

      assert html =~ "No items found"
    end
  end
end
