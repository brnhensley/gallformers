defmodule GallformersWeb.SearchLive do
  @moduledoc """
  LiveView for global search across all entity types.

  Provides a unified search experience with:
  - Debounced search input
  - Results grouped by type (galls, hosts, sources, glossary, taxonomy, places)
  - Sortable results table
  - Keyboard navigation
  - URL sync via push_patch
  """
  use GallformersWeb, :live_view

  alias Gallformers.Search

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Search",
       page_description:
         "Search the Gallformers database - find galls, host plants, sources, glossary terms, and taxonomic information.",
       page_url: "/globalsearch",
       page_image: nil,
       page_json_ld: nil,
       page_noindex: true,
       query: "",
       results: [],
       total_count: 0,
       sort_by: :relevance,
       sort_dir: :asc,
       selected_index: -1,
       loading: false
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    query = params["q"] || ""

    socket =
      if query != socket.assigns.query do
        perform_search(socket, query)
      else
        socket
      end

    {:noreply, assign(socket, query: query)}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    # Update URL with the search query, triggering handle_params
    {:noreply, push_patch(socket, to: ~p"/globalsearch?#{%{q: query}}")}
  end

  @impl true
  def handle_event("search_input", %{"q" => query}, socket) do
    # Debounce is handled by phx-debounce on the input
    # This just updates the URL when debounce fires
    {:noreply, push_patch(socket, to: ~p"/globalsearch?#{%{q: query}}")}
  end

  @impl true
  def handle_event("sort", %{"column" => column}, socket) do
    column_atom = String.to_existing_atom(column)

    {new_sort_by, new_sort_dir} =
      if socket.assigns.sort_by == column_atom do
        new_dir = if socket.assigns.sort_dir == :asc, do: :desc, else: :asc
        {column_atom, new_dir}
      else
        {column_atom, :asc}
      end

    {:noreply, assign(socket, sort_by: new_sort_by, sort_dir: new_sort_dir, selected_index: -1)}
  end

  @impl true
  def handle_event("keydown", %{"key" => "ArrowDown"}, socket) do
    max_index = length(socket.assigns.results) - 1
    new_index = min(socket.assigns.selected_index + 1, max_index)
    {:noreply, assign(socket, selected_index: new_index)}
  end

  @impl true
  def handle_event("keydown", %{"key" => "ArrowUp"}, socket) do
    new_index = max(socket.assigns.selected_index - 1, -1)
    {:noreply, assign(socket, selected_index: new_index)}
  end

  @impl true
  def handle_event("keydown", %{"key" => "Enter"}, socket) do
    selected_index = socket.assigns.selected_index

    if selected_index >= 0 do
      sorted =
        sorted_results(socket.assigns.results, socket.assigns.sort_by, socket.assigns.sort_dir)

      case Enum.at(sorted, selected_index) do
        nil ->
          {:noreply, socket}

        result ->
          {:noreply, push_navigate(socket, to: result_link(result))}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("keydown", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_result", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    {:noreply, assign(socket, selected_index: index)}
  end

  defp perform_search(socket, query) do
    trimmed = String.trim(query)

    if trimmed == "" do
      assign(socket,
        results: [],
        total_count: 0,
        selected_index: -1
      )
    else
      grouped = Search.global_search(trimmed)
      results = flatten_results(grouped)

      assign(socket,
        results: results,
        total_count: length(results),
        selected_index: -1
      )
    end
  end

  defp flatten_results(grouped) do
    galls = Enum.map(grouped.galls, &Map.put(&1, :category, "Gall"))
    hosts = Enum.map(grouped.hosts, &Map.put(&1, :category, "Host"))
    glossary = Enum.map(grouped.glossary, &Map.put(&1, :category, "Glossary"))
    sources = Enum.map(grouped.sources, &Map.put(&1, :category, "Source"))

    taxonomy =
      Enum.map(grouped.taxonomy, fn t ->
        category =
          case t.type do
            "genus" -> "Genus"
            "family" -> "Family"
            "section" -> "Section"
            _ -> "Taxonomy"
          end

        Map.put(t, :category, category)
      end)

    places = Enum.map(grouped.places, &Map.put(&1, :category, "Place"))

    galls ++ hosts ++ glossary ++ sources ++ taxonomy ++ places
  end

  defp sorted_results(results, sort_by, sort_dir) do
    sorted =
      Enum.sort_by(results, fn result ->
        case sort_by do
          :type -> result.category
          :name -> String.downcase(result.name || "")
          :relevance -> {result.match_score || 2, String.downcase(result.name || "")}
          _ -> String.downcase(result.name || "")
        end
      end)

    if sort_dir == :desc, do: Enum.reverse(sorted), else: sorted
  end

  @type_icons %{
    "gall" => "gf-gall",
    "host" => "gf-host",
    "glossary" => "ph-book-open",
    "source" => "ph-file-text",
    "genus" => "ph-folder",
    "family" => "ph-folder",
    "section" => "ph-folder",
    "place" => "ph-map-pin"
  }

  defp result_link(%{type: "glossary", name: name}), do: ~p"/glossary##{String.downcase(name)}"
  defp result_link(%{type: type, id: id}), do: build_entity_link(type, id)

  defp build_entity_link(type, id) when type in ~w(gall host source genus family section place) do
    "/#{type}/#{id}"
  end

  defp build_entity_link(_type, _id), do: "/"

  defp type_icon(type), do: Map.get(@type_icons, type, "ph-question")

  defp format_name(result) do
    case result.type do
      "gall" -> result.name
      "host" -> result.name
      "genus" -> "Genus #{result.name}"
      "section" -> "Section #{result.name}"
      "family" -> "Family #{result.name}"
      _ -> result.name
    end
  end

  defp italicized?(type) do
    type in ["gall", "host", "genus", "section"]
  end

  @impl true
  def render(assigns) do
    sorted = sorted_results(assigns.results, assigns.sort_by, assigns.sort_dir)
    assigns = assign(assigns, :sorted_results, sorted)

    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div id="search-container" phx-window-keydown="keydown">
        <h1 class="text-3xl font-bold text-gf-maroon mb-6">Search</h1>

        <form id="search-form" phx-submit="search" phx-change="search_input" class="mb-6">
          <.search_input
            id="global-search"
            name="q"
            value={@query}
            placeholder="Search for galls, hosts, sources, glossary terms..."
            phx-debounce="300"
          />
        </form>

        <div id="search-results-area">
          <%= if @query == "" do %>
            <div id="search-empty-state" class="bg-gray-50 rounded-lg p-8 text-center text-gray-600">
              <.icon name="ph-magnifying-glass" class="w-12 h-12 mx-auto mb-4 text-gray-400" />
              <p class="text-lg">
                Enter a search term to find galls, hosts, sources, glossary entries, and more.
              </p>
            </div>
          <% else %>
            <%= if @total_count == 0 do %>
              <div
                id="search-no-results"
                class="bg-gray-50 border border-gray-200 px-6 py-4 rounded-lg"
              >
                <p class="font-medium text-gray-900">No results for "{@query}"</p>
                <p class="text-sm text-gray-600 mt-1">
                  Try adjusting your search terms or use fewer keywords.
                </p>
              </div>
            <% else %>
              <div id="results-count" class="mb-4 text-sm text-gray-600">
                Found {@total_count} result{if @total_count != 1, do: "s", else: ""} for "{@query}"
              </div>

              <div class="bg-white rounded-lg shadow overflow-hidden">
                <table class="gf-table" id="results-table">
                  <thead>
                    <tr>
                      <th
                        class="cursor-pointer hover:bg-gray-100 w-32"
                        phx-click="sort"
                        phx-value-column="type"
                      >
                        Type
                        <%= if @sort_by == :type do %>
                          <span class="ml-1">{if @sort_dir == :asc, do: "↑", else: "↓"}</span>
                        <% end %>
                      </th>
                      <th
                        class="cursor-pointer hover:bg-gray-100"
                        phx-click="sort"
                        phx-value-column="name"
                      >
                        Name
                        <%= if @sort_by == :name do %>
                          <span class="ml-1">{if @sort_dir == :asc, do: "↑", else: "↓"}</span>
                        <% end %>
                      </th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for {result, index} <- Enum.with_index(@sorted_results) do %>
                      <tr
                        id={"result-#{index}"}
                        class={[
                          "cursor-pointer",
                          if(index == @selected_index, do: "!bg-canary")
                        ]}
                        phx-click="select_result"
                        phx-value-index={index}
                      >
                        <td>
                          <div class="flex items-center gap-2">
                            <.icon name={type_icon(result.type)} class="w-5 h-5 text-gray-500" />
                            <span class="text-gray-600">{result.category}</span>
                          </div>
                        </td>
                        <td>
                          <.link
                            href={result_link(result)}
                            class="text-gf-maroon hover:underline"
                          >
                            <%= if italicized?(result.type) do %>
                              <em>{format_name(result)}</em>
                            <% else %>
                              {format_name(result)}
                            <% end %>
                          </.link>
                          <%= if Map.get(result, :aliases, []) != [] do %>
                            <span class="text-sm text-gray-500 ml-2">
                              (also: {Enum.join(result.aliases, ", ")})
                            </span>
                          <% end %>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>

              <div class="mt-4 text-xs text-gray-500">
                <p>
                  <kbd class="px-1.5 py-0.5 bg-gray-100 border border-gray-300 rounded text-xs">
                    ↑
                  </kbd>
                  <kbd class="px-1.5 py-0.5 bg-gray-100 border border-gray-300 rounded text-xs">
                    ↓
                  </kbd>
                  to navigate,
                  <kbd class="px-1.5 py-0.5 bg-gray-100 border border-gray-300 rounded text-xs">
                    Enter
                  </kbd>
                  to select
                </p>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
