defmodule GallformersWeb.Admin.TaxonomyLive.Index do
  @moduledoc """
  Admin page for listing and managing taxonomic classifications.

  Displays families, genera, and sections with their hierarchical relationships.
  """
  use GallformersWeb, :live_view

  alias Gallformers.Taxonomy

  @page_size 50
  @valid_sort_columns ~w(name type description parent_name)

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
      |> assign(:current_page, 1)
      |> assign(:page_size, @page_size)
      |> assign(:sort_by, :name)
      |> assign(:sort_dir, :asc)
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
      |> assign(:current_page, 1)
      |> load_taxonomies()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_type", %{"type" => type}, socket) do
    filter_type = if type == "", do: nil, else: type

    socket =
      socket
      |> assign(:filter_type, filter_type)
      |> assign(:current_page, 1)
      |> load_taxonomies()

    {:noreply, socket}
  end

  @impl true
  def handle_event("page", %{"page" => page}, socket) do
    page = max(1, min(page, total_pages(socket.assigns.taxonomies, socket.assigns.page_size)))
    {:noreply, assign(socket, current_page: page)}
  end

  @impl true
  def handle_event("sort", %{"column" => column}, socket) when column in @valid_sort_columns do
    column_atom = String.to_atom(column)

    {new_sort_by, new_sort_dir} =
      if socket.assigns.sort_by == column_atom do
        new_dir = if socket.assigns.sort_dir == :asc, do: :desc, else: :asc
        {column_atom, new_dir}
      else
        {column_atom, :asc}
      end

    {:noreply,
     socket
     |> assign(:sort_by, new_sort_by)
     |> assign(:sort_dir, new_sort_dir)
     |> assign(:current_page, 1)}
  end

  @impl true
  def handle_event("delete", %{"id" => _id}, socket) do
    # Taxonomy deletion is disabled until soft delete is implemented
    # Deleting taxonomy entries can cascade to hundreds of downstream records
    {:noreply,
     put_flash(
       socket,
       :error,
       "Taxonomy deletion is temporarily disabled. Deleting a family or genus can cascade to " <>
         "hundreds of species records. This will be re-enabled once soft delete is implemented."
     )}
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
    Taxonomy.search_taxonomies(query, type, 500)
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

  defp sorted_taxonomies(taxonomies, sort_by, sort_dir) do
    sorted =
      Enum.sort_by(taxonomies, fn t ->
        value =
          case sort_by do
            :name -> t.name
            :type -> t.type
            :description -> t.description
            :parent_name -> t.parent_name
            _ -> t.name
          end

        if is_binary(value), do: String.downcase(value), else: value || ""
      end)

    if sort_dir == :desc, do: Enum.reverse(sorted), else: sorted
  end

  defp paginated_taxonomies(taxonomies, current_page, page_size, sort_by, sort_dir) do
    taxonomies
    |> sorted_taxonomies(sort_by, sort_dir)
    |> Enum.drop((current_page - 1) * page_size)
    |> Enum.take(page_size)
  end

  defp total_pages(taxonomies, page_size) do
    max(1, ceil(length(taxonomies) / page_size))
  end

  defp taxonomy_public_url(%{type: "family", id: id}), do: ~p"/family/#{id}"
  defp taxonomy_public_url(%{type: "genus", id: id}), do: ~p"/genus/#{id}"
  defp taxonomy_public_url(%{type: "section", id: id}), do: ~p"/section/#{id}"
  defp taxonomy_public_url(_), do: nil

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} page_title="Taxonomy">
      <div class="space-y-6">
        <%!-- Header with search, filter, and new button --%>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div class="flex items-center gap-4 flex-1 max-w-2xl">
            <form phx-change="search" phx-submit="search" id="taxonomy-search-form" class="flex-1">
              <.search_input
                id="taxonomy-search"
                name="query"
                value={@search_query}
                placeholder="Search taxonomy..."
                phx-debounce="300"
              />
            </form>
            <form phx-change="filter_type">
              <.input
                type="select"
                name="type"
                prompt="All Types"
                options={[{"Families", "family"}, {"Genera", "genus"}, {"Sections", "section"}]}
                value={@filter_type}
              />
            </form>
          </div>
          <.link navigate={~p"/admin/taxonomy/new"} class="gf-btn gf-btn-primary">
            New Entry
          </.link>
        </div>

        <%!-- Taxonomy list table --%>
        <div class="bg-white shadow rounded-lg overflow-hidden">
          <table class="gf-table gf-table-dark">
            <thead>
              <tr>
                <th class="sortable" phx-click="sort" phx-value-column="name">
                  Name
                  <span :if={@sort_by == :name} class="ml-1">
                    {if @sort_dir == :asc, do: "↑", else: "↓"}
                  </span>
                </th>
                <th class="sortable" phx-click="sort" phx-value-column="type">
                  Type
                  <span :if={@sort_by == :type} class="ml-1">
                    {if @sort_dir == :asc, do: "↑", else: "↓"}
                  </span>
                </th>
                <th class="sortable" phx-click="sort" phx-value-column="description">
                  Description
                  <span :if={@sort_by == :description} class="ml-1">
                    {if @sort_dir == :asc, do: "↑", else: "↓"}
                  </span>
                </th>
                <th class="sortable" phx-click="sort" phx-value-column="parent_name">
                  Parent
                  <span :if={@sort_by == :parent_name} class="ml-1">
                    {if @sort_dir == :asc, do: "↑", else: "↓"}
                  </span>
                </th>
                <th class="text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={
                taxonomy <-
                  paginated_taxonomies(@taxonomies, @current_page, @page_size, @sort_by, @sort_dir)
              }>
                <td>
                  <.link
                    navigate={~p"/admin/taxonomy/#{taxonomy.id}"}
                    class="hover:underline font-medium"
                  >
                    {taxonomy.name}
                  </.link>
                </td>
                <td>
                  <.type_badge type={taxonomy.type} />
                </td>
                <td class="text-gray-500">
                  {taxonomy.description || "—"}
                </td>
                <td>
                  <%= if taxonomy.parent_name do %>
                    <span class="text-gray-900">{taxonomy.parent_name}</span>
                    <span class="text-gray-500 text-xs ml-1">({taxonomy.parent_type})</span>
                  <% else %>
                    <span class="text-gray-400">—</span>
                  <% end %>
                </td>
                <td class="text-right">
                  <.table_actions>
                    <.action_button
                      icon="ph-pencil-simple"
                      label="Edit"
                      navigate={~p"/admin/taxonomy/#{taxonomy.id}"}
                      variant="primary"
                    />
                    <.action_button
                      icon="ph-arrow-square-out"
                      label="View"
                      navigate={taxonomy_public_url(taxonomy)}
                    />
                    <.action_button
                      icon="ph-trash"
                      label="Delete"
                      variant="danger"
                      phx-click="delete"
                      phx-value-id={taxonomy.id}
                    />
                  </.table_actions>
                </td>
              </tr>
              <tr :if={@taxonomies == []}>
                <td colspan="5" class="text-center text-gray-500">
                  No taxonomy entries found.
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <%= if total_pages(@taxonomies, @page_size) > 1 do %>
          <.pagination
            page={@current_page}
            total_pages={total_pages(@taxonomies, @page_size)}
            total_items={length(@taxonomies)}
            page_size={@page_size}
            on_page_change={fn page -> JS.push("page", value: %{page: page}) end}
          />
        <% else %>
          <p class="text-sm text-gray-500">
            Showing {length(@taxonomies)} entries
          </p>
        <% end %>
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
