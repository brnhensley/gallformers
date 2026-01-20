defmodule GallformersWeb.ExploreLive do
  @moduledoc """
  LiveView for exploring galls and hosts by taxonomic hierarchy.

  Provides three browse tabs:
  - Galls: All described gall species organized by Family → Genus → Species
  - Undescribed: Undescribed gall species
  - Hosts: Host plant species organized by Family → Genus → Species

  Uses an expandable tree UI for navigation.
  """
  use GallformersWeb, :live_view

  alias Gallformers.Explore

  @tabs ~w(galls undescribed hosts)

  @impl true
  def mount(_params, _session, socket) do
    # Load all tree data on mount
    galls_tree = Explore.get_galls_tree()
    undescribed_tree = Explore.get_undescribed_tree()
    hosts_tree = Explore.get_hosts_tree()

    {:ok,
     assign(socket,
       page_title: "Explore",
       page_description:
         "Explore the Gallformers database - browse galls and host plants organized by taxonomic family, genus, and species.",
       page_url: "/explore",
       page_image: nil,
       page_json_ld: nil,
       tabs: @tabs,
       active_tab: "galls",
       search_query: "",
       galls_tree: galls_tree,
       undescribed_tree: undescribed_tree,
       hosts_tree: hosts_tree,
       galls_expanded: MapSet.new(),
       undescribed_expanded: MapSet.new(),
       hosts_expanded: MapSet.new()
     )}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) when tab in @tabs do
    {:noreply, assign(socket, active_tab: tab)}
  end

  @impl true
  def handle_event("switch_tab", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_node", %{"key" => key, "tab" => tab}, socket) do
    expanded_key = expanded_key_for_tab(tab)
    current_expanded = Map.get(socket.assigns, expanded_key, MapSet.new())

    new_expanded =
      if MapSet.member?(current_expanded, key) do
        MapSet.delete(current_expanded, key)
      else
        MapSet.put(current_expanded, key)
      end

    {:noreply, assign(socket, [{expanded_key, new_expanded}])}
  end

  @impl true
  def handle_event("expand_all", %{"tab" => tab}, socket) do
    tree = tree_for_tab(socket.assigns, tab)
    all_keys = collect_branch_keys(tree)
    expanded_key = expanded_key_for_tab(tab)

    {:noreply, assign(socket, [{expanded_key, MapSet.new(all_keys)}])}
  end

  @impl true
  def handle_event("collapse_all", %{"tab" => tab}, socket) do
    expanded_key = expanded_key_for_tab(tab)
    {:noreply, assign(socket, [{expanded_key, MapSet.new()}])}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    # When searching, auto-expand matching branches
    if String.trim(query) != "" do
      tree = tree_for_tab(socket.assigns, socket.assigns.active_tab)
      matching_keys = collect_matching_branch_keys(tree, query)
      expanded_key = expanded_key_for_tab(socket.assigns.active_tab)
      socket = assign(socket, :search_query, query)
      {:noreply, assign(socket, [{expanded_key, MapSet.new(matching_keys)}])}
    else
      {:noreply, assign(socket, search_query: query)}
    end
  end

  defp expanded_key_for_tab("galls"), do: :galls_expanded
  defp expanded_key_for_tab("undescribed"), do: :undescribed_expanded
  defp expanded_key_for_tab("hosts"), do: :hosts_expanded

  defp tree_for_tab(assigns, "galls"), do: assigns.galls_tree
  defp tree_for_tab(assigns, "undescribed"), do: assigns.undescribed_tree
  defp tree_for_tab(assigns, "hosts"), do: assigns.hosts_tree

  defp collect_branch_keys(nodes) do
    Enum.flat_map(nodes, fn node ->
      if Map.has_key?(node, :nodes) and node.nodes != [] do
        [node.key | collect_branch_keys(node.nodes)]
      else
        []
      end
    end)
  end

  defp collect_matching_branch_keys(nodes, query) do
    query_lower = String.downcase(query)

    nodes
    |> Enum.flat_map(&collect_node_keys(&1, query, query_lower))
    |> Enum.filter(&(&1 != :match))
  end

  defp collect_node_keys(node, query, query_lower) do
    if branch_node?(node) do
      collect_branch_matching_keys(node, query, query_lower)
    else
      if label_matches?(node.label, query_lower), do: [:match], else: []
    end
  end

  defp collect_branch_matching_keys(node, query, query_lower) do
    child_keys = collect_matching_branch_keys(node.nodes, query)

    if child_keys != [] or label_matches?(node.label, query_lower),
      do: [node.key | child_keys],
      else: []
  end

  defp filter_tree(nodes, ""), do: nodes

  defp filter_tree(nodes, query) do
    query_lower = String.downcase(query)

    nodes
    |> Enum.map(&filter_node(&1, query, query_lower))
    |> Enum.reject(&is_nil/1)
  end

  defp filter_node(node, query, query_lower) do
    if branch_node?(node) do
      filter_branch_node(node, query, query_lower)
    else
      if label_matches?(node.label, query_lower), do: node, else: nil
    end
  end

  defp filter_branch_node(node, query, query_lower) do
    filtered_children = filter_tree(node.nodes, query)

    if filtered_children != [] or label_matches?(node.label, query_lower) do
      %{node | nodes: filtered_children}
    else
      nil
    end
  end

  defp branch_node?(node), do: Map.has_key?(node, :nodes) and node.nodes != []

  defp label_matches?(label, query_lower),
    do: String.contains?(String.downcase(label), query_lower)

  defp tab_label("galls"), do: "Galls"
  defp tab_label("undescribed"), do: "Undescribed"
  defp tab_label("hosts"), do: "Hosts"

  defp tab_count(assigns, "galls"), do: count_species(assigns.galls_tree)
  defp tab_count(assigns, "undescribed"), do: count_species(assigns.undescribed_tree)
  defp tab_count(assigns, "hosts"), do: count_species(assigns.hosts_tree)

  defp count_species(tree) do
    Enum.reduce(tree, 0, fn family, acc ->
      acc +
        Enum.reduce(family.nodes, 0, fn genus, acc2 ->
          acc2 + length(genus.nodes)
        end)
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div id="explore-container">
        <p class="text-lg text-gray-600 mb-6">
          Browse galls and host plants organized by taxonomic family. Click on families and genera
          to expand and see species.
        </p>

        <%!-- Tabs --%>
        <div class="border-b border-gray-200 mb-4">
          <nav class="-mb-px flex space-x-8" aria-label="Tabs">
            <%= for tab <- @tabs do %>
              <button
                phx-click="switch_tab"
                phx-value-tab={tab}
                class={[
                  "whitespace-nowrap py-4 px-1 border-b-2 font-medium text-lg",
                  if(@active_tab == tab,
                    do: "border-gf-maroon text-gf-maroon",
                    else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                  )
                ]}
                aria-current={if @active_tab == tab, do: "page", else: false}
              >
                {tab_label(tab)}
                <span class={[
                  "ml-2 py-0.5 px-2 rounded-full text-xs",
                  if(@active_tab == tab,
                    do: "bg-gf-maroon text-white",
                    else: "bg-gray-100 text-gray-600"
                  )
                ]}>
                  {tab_count(assigns, tab)}
                </span>
              </button>
            <% end %>
          </nav>
        </div>

        <%!-- Search and controls --%>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-4">
          <div class="flex-1 max-w-md">
            <form phx-change="search" phx-submit="search" id="explore-search-form">
              <.search_input
                id="explore-search"
                name="query"
                value={@search_query}
                placeholder="Filter by name..."
                phx-debounce="300"
              />
            </form>
          </div>
          <div class="flex gap-2">
            <button
              phx-click="expand_all"
              phx-value-tab={@active_tab}
              class="text-sm hover:underline"
            >
              Expand All
            </button>
            <span class="text-gray-300">|</span>
            <button
              phx-click="collapse_all"
              phx-value-tab={@active_tab}
              class="text-sm hover:underline"
            >
              Collapse All
            </button>
          </div>
        </div>

        <%!-- Tree content --%>
        <div class="bg-white rounded-lg border border-gray-200 p-4">
          <%= case @active_tab do %>
            <% "galls" -> %>
              <% filtered = filter_tree(@galls_tree, @search_query) %>
              <%= if filtered == [] do %>
                <p class="text-gray-500 italic">
                  {if @search_query != "",
                    do: "No matching gall species found.",
                    else: "No gall species found."}
                </p>
              <% else %>
                <.tree_menu
                  nodes={filtered}
                  expanded={@galls_expanded}
                  tab="galls"
                  level={0}
                />
              <% end %>
            <% "undescribed" -> %>
              <% filtered = filter_tree(@undescribed_tree, @search_query) %>
              <%= if filtered == [] do %>
                <p class="text-gray-500 italic">
                  {if @search_query != "",
                    do: "No matching undescribed gall species found.",
                    else: "No undescribed gall species found."}
                </p>
              <% else %>
                <.tree_menu
                  nodes={filtered}
                  expanded={@undescribed_expanded}
                  tab="undescribed"
                  level={0}
                />
              <% end %>
            <% "hosts" -> %>
              <% filtered = filter_tree(@hosts_tree, @search_query) %>
              <%= if filtered == [] do %>
                <p class="text-gray-500 italic">
                  {if @search_query != "",
                    do: "No matching host species found.",
                    else: "No host species found."}
                </p>
              <% else %>
                <.tree_menu
                  nodes={filtered}
                  expanded={@hosts_expanded}
                  tab="hosts"
                  level={0}
                />
              <% end %>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :nodes, :list, required: true
  attr :expanded, :any, required: true
  attr :tab, :string, required: true
  attr :level, :integer, required: true

  defp tree_menu(assigns) do
    ~H"""
    <ul class={["list-none", if(@level > 0, do: "ml-5", else: "")]}>
      <%= for node <- @nodes do %>
        <li class="py-1">
          <%= if Map.has_key?(node, :nodes) and node.nodes != [] do %>
            <%!-- Branch node (family or genus) --%>
            <button
              phx-click="toggle_node"
              phx-value-key={node.key}
              phx-value-tab={@tab}
              class="flex items-center gap-1 text-left hover:text-gf-maroon focus:outline-none focus:text-gf-maroon"
            >
              <span class={[
                "inline-block w-4 h-4 transition-transform",
                if(MapSet.member?(@expanded, node.key), do: "rotate-90", else: "")
              ]}>
                <.icon name="ph-caret-right" class="w-4 h-4" />
              </span>
              <span class={[
                "font-medium",
                if(String.starts_with?(node.key, "f-"), do: "text-gf-maroon", else: "")
              ]}>
                {node.label}
              </span>
              <span class="text-xs text-gray-400 ml-1">
                ({length(node.nodes)})
              </span>
            </button>
            <%= if MapSet.member?(@expanded, node.key) do %>
              <.tree_menu nodes={node.nodes} expanded={@expanded} tab={@tab} level={@level + 1} />
            <% end %>
          <% else %>
            <%!-- Leaf node (species) --%>
            <.link
              href={node.url}
              class="flex items-center gap-1 ml-5 hover:underline"
            >
              <em>{node.label}</em>
            </.link>
          <% end %>
        </li>
      <% end %>
    </ul>
    """
  end
end
