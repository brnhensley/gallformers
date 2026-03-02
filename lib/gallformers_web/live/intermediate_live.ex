defmodule GallformersWeb.IntermediateLive do
  @moduledoc """
  LiveView for the public intermediate taxonomy browse page.

  Displays an intermediate rank (subfamily, tribe, etc.) with its
  breadcrumb lineage and list of children (genera and sub-intermediates).
  """
  use GallformersWeb, :live_view

  alias Gallformers.Taxonomy
  alias Gallformers.Taxonomy.Lineage

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Integer.parse(id) do
      {taxonomy_id, ""} ->
        load_intermediate(socket, taxonomy_id)

      _ ->
        {:ok, assign_not_found(socket, "Invalid taxonomy ID")}
    end
  end

  defp load_intermediate(socket, taxonomy_id) do
    case Taxonomy.get_taxonomy(taxonomy_id) do
      %{type: "intermediate"} = taxonomy ->
        path = Taxonomy.get_taxonomy_path(taxonomy_id)
        lineage = Lineage.from_path(path)
        children = Taxonomy.list_children_with_counts(taxonomy_id)

        {:ok,
         assign(socket,
           page_title: "#{taxonomy.rank}: #{taxonomy.name}",
           page_description:
             "#{taxonomy.name} - A taxonomic #{String.downcase(taxonomy.rank || "group")} documented on Gallformers.",
           page_url: "/taxonomy/#{taxonomy_id}",
           page_image: nil,
           page_json_ld: nil,
           page_noindex: false,
           taxonomy: taxonomy,
           lineage: lineage,
           children: children,
           filtered_children: children,
           total_children_count: length(children),
           search_query: "",
           sort_by: :name,
           sort_dir: :asc,
           error: nil
         )}

      _ ->
        {:ok, assign_not_found(socket, "Taxonomy not found")}
    end
  end

  defp assign_not_found(socket, error) do
    assign(socket,
      page_title: "Not Found",
      page_description: "The requested taxonomy was not found on Gallformers.",
      page_url: nil,
      page_image: nil,
      page_json_ld: nil,
      page_noindex: true,
      taxonomy: nil,
      lineage: nil,
      children: [],
      filtered_children: [],
      total_children_count: 0,
      search_query: "",
      sort_by: :name,
      sort_dir: :asc,
      error: error
    )
  end

  defp child_url(%{type: "genus", id: id}), do: "/genus/#{id}"
  defp child_url(%{type: "intermediate", id: id}), do: "/taxonomy/#{id}"
  defp child_url(%{type: "section", id: id}), do: "/section/#{id}"
  defp child_url(_), do: nil

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    {:noreply,
     socket
     |> assign(:search_query, query)
     |> filter_children()}
  end

  @impl true
  def handle_event("sort", %{"column" => column}, socket)
      when column in ["name", "type", "species_count"] do
    column_atom = String.to_atom(column)

    {new_sort_by, new_sort_dir} =
      if socket.assigns.sort_by == column_atom do
        new_dir = if socket.assigns.sort_dir == :asc, do: :desc, else: :asc
        {column_atom, new_dir}
      else
        {column_atom, :asc}
      end

    {:noreply, assign(socket, sort_by: new_sort_by, sort_dir: new_sort_dir)}
  end

  defp filter_children(socket) do
    query = String.downcase(socket.assigns.search_query)

    filtered =
      if query == "" do
        socket.assigns.children
      else
        Enum.filter(socket.assigns.children, fn c ->
          String.contains?(String.downcase(c.name), query) ||
            (c.description && String.contains?(String.downcase(c.description), query)) ||
            (c.rank && String.contains?(String.downcase(c.rank), query))
        end)
      end

    assign(socket, :filtered_children, filtered)
  end

  defp sorted_children(children, sort_by, sort_dir) do
    sorted =
      Enum.sort_by(children, fn c ->
        case sort_by do
          :name -> String.downcase(c.name || "")
          :type -> String.downcase(c.rank || c.type || "")
          :species_count -> c.species_count
          _ -> String.downcase(c.name || "")
        end
      end)

    if sort_dir == :desc, do: Enum.reverse(sorted), else: sorted
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="mx-auto max-w-7xl">
        <%= if @error do %>
          <div class="bg-red-50 border border-red-200 rounded-lg p-4 text-red-700">{@error}</div>
        <% else %>
          <%= if @taxonomy do %>
            <%!-- Header --%>
            <div class="mb-6">
              <div class="flex items-center gap-2 mb-2">
                <h1 class="text-2xl font-bold text-gf-maroon">
                  <span class="text-lg font-normal text-gray-600">{@taxonomy.rank}:</span>
                  {@taxonomy.name}
                </h1>
                <.link
                  :if={@current_user}
                  href={~p"/admin/taxonomy/#{@taxonomy.id}"}
                  class="text-gray-400 hover:text-gf-maroon"
                  title="Edit in admin"
                >
                  <.icon name="ph-pencil-simple" class="h-5 w-5" />
                </.link>
              </div>

              <%!-- Breadcrumb --%>
              <.taxonomy_breadcrumb
                family={@lineage && @lineage.family}
                intermediates={
                  if @lineage,
                    do: Enum.reject(@lineage.intermediates, &(&1.id == @taxonomy.id)),
                    else: []
                }
              />
            </div>

            <%!-- Children list --%>
            <div class="mt-6">
              <%= if @total_children_count > 0 do %>
                <h2 class="text-lg font-semibold text-gray-800 mb-3">
                  Children ({@total_children_count})
                </h2>

                <%!-- Search box --%>
                <div class="mb-4 max-w-md">
                  <form phx-change="search" phx-submit="search" id="intermediate-search-form">
                    <.search_input
                      id="intermediate-search"
                      name="query"
                      value={@search_query}
                      placeholder="Filter by name, type, or description..."
                      phx-debounce="300"
                    />
                  </form>
                </div>

                <%= if Enum.empty?(@filtered_children) do %>
                  <div class="bg-gray-50 rounded-lg p-8 text-center text-gray-600">
                    <p>No children found matching "{@search_query}"</p>
                  </div>
                <% else %>
                  <div class="bg-white rounded border border-gray-200 overflow-hidden">
                    <table class="gf-table">
                      <thead>
                        <tr>
                          <th class="sortable" phx-click="sort" phx-value-column="name">
                            Name
                            <span :if={@sort_by == :name} class="ml-1">
                              {if @sort_dir == :asc, do: "↑", else: "↓"}
                            </span>
                          </th>
                          <th
                            class="sortable text-center"
                            phx-click="sort"
                            phx-value-column="type"
                          >
                            Type
                            <span :if={@sort_by == :type} class="ml-1">
                              {if @sort_dir == :asc, do: "↑", else: "↓"}
                            </span>
                          </th>
                          <th
                            class="sortable text-center"
                            phx-click="sort"
                            phx-value-column="species_count"
                          >
                            Species
                            <span :if={@sort_by == :species_count} class="ml-1">
                              {if @sort_dir == :asc, do: "↑", else: "↓"}
                            </span>
                          </th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr :for={
                          child <- sorted_children(@filtered_children, @sort_by, @sort_dir)
                        }>
                          <td>
                            <.link href={child_url(child)} class="hover:underline font-medium">
                              <.taxon_name name={child.name} rank={child.type} />
                            </.link>
                            <span
                              :if={child.description not in [nil, ""]}
                              class="text-gray-500 text-sm ml-1"
                            >
                              ({child.description})
                            </span>
                          </td>
                          <td class="text-center">
                            <span class="text-sm text-gray-600">
                              {child.rank || child.type}
                            </span>
                          </td>
                          <td class="text-center text-gray-600">
                            {child.species_count}
                          </td>
                        </tr>
                      </tbody>
                    </table>
                  </div>

                  <%!-- Filter status message --%>
                  <div class="mt-4 text-sm text-gray-500">
                    <%= if @search_query != "" do %>
                      Filtering {length(@filtered_children)} of {@total_children_count} children
                    <% else %>
                      Showing {length(@filtered_children)} children
                    <% end %>
                  </div>
                <% end %>
              <% else %>
                <p class="text-gray-500 italic">No children found.</p>
              <% end %>
            </div>
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
