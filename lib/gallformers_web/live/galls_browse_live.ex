defmodule GallformersWeb.GallsBrowseLive do
  @moduledoc """
  Browse all gall species organized by Family > Genus > Species.

  Includes a toggle to switch between described and undescribed galls.
  Uses a tree UI with search filtering and smart expand.
  """
  use GallformersWeb, :live_view

  alias Gallformers.Galls
  alias GallformersWeb.BrowseHelpers
  alias GallformersWeb.TreeComponents

  @impl true
  def mount(_params, _session, socket) do
    galls_tree = Galls.get_galls_tree()
    undescribed_tree = Galls.get_undescribed_tree()

    {:ok,
     assign(socket,
       page_title: "Galls",
       page_description: "Browse gall-forming species organized by family and genus.",
       page_url: "/galls",
       page_image: nil,
       page_json_ld: nil,
       showing_undescribed: false,
       search_query: "",
       galls_tree: galls_tree,
       undescribed_tree: undescribed_tree,
       filtered: galls_tree,
       expanded: MapSet.new()
     )}
  end

  @impl true
  def handle_event("toggle_node", %{"key" => key}, socket) do
    expanded = toggle_set(socket.assigns.expanded, key)
    {:noreply, assign(socket, expanded: expanded)}
  end

  @impl true
  def handle_event("expand_all", _params, socket) do
    all_keys = BrowseHelpers.collect_branch_keys(socket.assigns.filtered)
    {:noreply, assign(socket, expanded: MapSet.new(all_keys))}
  end

  @impl true
  def handle_event("collapse_all", _params, socket) do
    {:noreply, assign(socket, expanded: MapSet.new())}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    tree = active_tree(socket.assigns)
    filtered = BrowseHelpers.filter_tree(tree, query)
    expanded = BrowseHelpers.smart_expand(filtered, query, socket.assigns.expanded)

    {:noreply, assign(socket, search_query: query, filtered: filtered, expanded: expanded)}
  end

  @impl true
  def handle_event("toggle_undescribed", _params, socket) do
    new_showing = !socket.assigns.showing_undescribed
    tree = if new_showing, do: socket.assigns.undescribed_tree, else: socket.assigns.galls_tree
    query = socket.assigns.search_query
    filtered = BrowseHelpers.filter_tree(tree, query)

    expanded =
      if query != "",
        do: BrowseHelpers.smart_expand(filtered, query, MapSet.new()),
        else: MapSet.new()

    {:noreply,
     assign(socket,
       showing_undescribed: new_showing,
       filtered: filtered,
       expanded: expanded
     )}
  end

  defp active_tree(assigns) do
    if assigns.showing_undescribed, do: assigns.undescribed_tree, else: assigns.galls_tree
  end

  defp toggle_set(set, key) do
    if MapSet.member?(set, key), do: MapSet.delete(set, key), else: MapSet.put(set, key)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div id="galls-browse-container">
        <div class="flex items-center justify-between mb-6">
          <p class="text-lg text-gray-600">
            Browse gall-forming species by family and genus.
          </p>
          <button
            phx-click="toggle_undescribed"
            class={[
              "px-3 py-1.5 rounded-md text-sm font-medium border transition-colors",
              if(@showing_undescribed,
                do: "bg-gf-maroon text-white border-gf-maroon",
                else: "bg-white text-gray-700 border-gray-300 hover:bg-gray-50"
              )
            ]}
            data-active-view={if @showing_undescribed, do: "undescribed", else: "described"}
          >
            Undescribed
          </button>
        </div>

        <TreeComponents.tree_browser
          id="galls-browse"
          nodes={@filtered}
          expanded={@expanded}
          search_query={@search_query}
          show_search={true}
          show_controls={true}
          on_toggle="toggle_node"
          on_expand_all="expand_all"
          on_collapse_all="collapse_all"
          on_search="search"
        />
      </div>
    </Layouts.app>
    """
  end
end
