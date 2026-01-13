defmodule GallformersWeb.Admin.TaxonomyLive.Index do
  @moduledoc """
  Admin page for listing and managing taxonomic classifications.

  Displays families, genera, and sections with their hierarchical relationships.
  """
  use GallformersWeb, :live_view

  alias Gallformers.Taxonomy

  @impl true
  def mount(_params, session, socket) do
    current_user = session["current_user"]

    if connected?(socket), do: Taxonomy.subscribe()

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:page_title, "Taxonomy")
      |> assign(:search_query, "")
      |> assign(:filter_type, nil)
      |> load_taxonomies()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Taxonomy")
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    socket =
      socket
      |> assign(:search_query, query)
      |> load_taxonomies()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_type", %{"type" => type}, socket) do
    filter_type = if type == "", do: nil, else: type

    socket =
      socket
      |> assign(:filter_type, filter_type)
      |> load_taxonomies()

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    taxonomy = Taxonomy.get_taxonomy!(String.to_integer(id))

    case Taxonomy.delete_taxonomy(taxonomy) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Taxonomy deleted successfully")
         |> load_taxonomies()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete taxonomy")}
    end
  end

  @impl true
  def handle_info({event, _taxonomy}, socket)
      when event in [:taxonomy_created, :taxonomy_updated, :taxonomy_deleted] do
    {:noreply, load_taxonomies(socket)}
  end

  defp load_taxonomies(socket) do
    taxonomies =
      case {socket.assigns.search_query, socket.assigns.filter_type} do
        {"", nil} -> Taxonomy.list_taxonomies_with_parent()
        {"", type} -> Taxonomy.list_taxonomies_with_parent(type)
        {query, type} -> search_and_filter(query, type)
      end

    assign(socket, :taxonomies, taxonomies)
  end

  defp search_and_filter(query, type) do
    Taxonomy.search_taxonomies(query, type, 100)
    |> Enum.map(fn t ->
      parent = if t.parent_id, do: Taxonomy.get_taxonomy(t.parent_id), else: nil

      %{
        id: t.id,
        name: t.name,
        description: t.description,
        type: t.type,
        parent_id: t.parent_id,
        parent_name: parent && parent.name,
        parent_type: parent && parent.type
      }
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} page_title="Taxonomy">
      <div class="space-y-6">
        <%!-- Header with search, filter, and new button --%>
        <div class="flex flex-col sm:flex-row sm:items-center gap-4">
          <div class="flex-1 max-w-md">
            <form phx-change="search" phx-submit="search" id="taxonomy-search-form">
              <.input
                type="text"
                name="query"
                value={@search_query}
                placeholder="Search taxonomy..."
                phx-debounce="300"
              />
            </form>
          </div>
          <div>
            <form phx-change="filter_type" id="taxonomy-filter-form">
              <select
                name="type"
                class="block w-full rounded-md border-gray-300 shadow-sm focus:border-gf-maroon focus:ring-gf-maroon"
              >
                <option value="">All Types</option>
                <option value="family" selected={@filter_type == "family"}>Families</option>
                <option value="genus" selected={@filter_type == "genus"}>Genera</option>
                <option value="section" selected={@filter_type == "section"}>Sections</option>
              </select>
            </form>
          </div>
          <.link
            navigate={~p"/admin/taxonomy/new"}
            class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm !text-white !no-underline bg-gf-maroon hover:bg-gf-maroon/90 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gf-maroon"
          >
            <.icon name="hero-plus" class="h-5 w-5 mr-2" /> New Entry
          </.link>
        </div>

        <%!-- Taxonomy list table --%>
        <div class="bg-white shadow rounded-lg overflow-hidden">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-cadet-blue">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-white uppercase tracking-wider">
                  Name
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-white uppercase tracking-wider">
                  Type
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-white uppercase tracking-wider">
                  Description
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-white uppercase tracking-wider">
                  Parent
                </th>
                <th class="px-6 py-3 text-right text-xs font-medium text-white uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <tr :for={taxonomy <- @taxonomies} class="hover:bg-gray-50">
                <td class="px-6 py-4 whitespace-nowrap">
                  <.link
                    navigate={~p"/admin/taxonomy/#{taxonomy.id}"}
                    class="text-gf-maroon hover:underline font-medium"
                  >
                    {taxonomy.name}
                  </.link>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <.type_badge type={taxonomy.type} />
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-gray-500 text-sm">
                  {taxonomy.description || "—"}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm">
                  <%= if taxonomy.parent_name do %>
                    <span class="text-gray-900">{taxonomy.parent_name}</span>
                    <span class="text-gray-500 text-xs ml-1">({taxonomy.parent_type})</span>
                  <% else %>
                    <span class="text-gray-400">—</span>
                  <% end %>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                  <.link
                    navigate={~p"/admin/taxonomy/#{taxonomy.id}"}
                    class="text-gf-maroon hover:text-gf-autumn mr-4"
                  >
                    Edit
                  </.link>
                  <button
                    phx-click="delete"
                    phx-value-id={taxonomy.id}
                    data-confirm="Are you sure? This will also affect species in this taxonomy."
                    class="text-red-600 hover:text-red-900"
                  >
                    Delete
                  </button>
                </td>
              </tr>
              <tr :if={@taxonomies == []}>
                <td colspan="5" class="px-6 py-8 text-center text-gray-500">
                  No taxonomy entries found.
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <p class="text-sm text-gray-500">
          Showing {@taxonomies |> length()} entries
        </p>
      </div>
    </Layouts.admin>
    """
  end

  defp type_badge(assigns) do
    color_class =
      case assigns.type do
        "family" -> "bg-blue-100 text-blue-800"
        "genus" -> "bg-green-100 text-green-800"
        "section" -> "bg-purple-100 text-purple-800"
        _ -> "bg-gray-100 text-gray-800"
      end

    assigns = assign(assigns, :color_class, color_class)

    ~H"""
    <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{@color_class}"}>
      {@type}
    </span>
    """
  end
end
