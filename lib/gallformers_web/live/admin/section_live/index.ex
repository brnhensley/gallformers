defmodule GallformersWeb.Admin.SectionLive.Index do
  @moduledoc """
  Admin page for listing and managing taxonomy sections.

  Sections are used for host plants only (primarily Quercus oaks) to group
  species within a genus.
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
      |> assign(:page_title, "Sections")
      |> assign(:search_query, "")
      |> load_sections()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Sections")
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    socket =
      socket
      |> assign(:search_query, query)
      |> load_sections()

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    section = Taxonomy.get_taxonomy!(String.to_integer(id))

    case Taxonomy.delete_taxonomy(section) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Section deleted successfully")
         |> load_sections()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete section")}
    end
  end

  @impl true
  def handle_info({event, _entry}, socket)
      when event in [:taxonomy_created, :taxonomy_updated, :taxonomy_deleted, :section_updated] do
    {:noreply, load_sections(socket)}
  end

  defp load_sections(socket) do
    sections =
      case socket.assigns.search_query do
        "" -> Taxonomy.list_sections_with_details()
        query -> Taxonomy.search_sections(query)
      end

    assign(socket, :sections, sections)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} page_title="Sections">
      <div class="space-y-6">
        <%!-- Header with search and new button --%>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div class="flex-1 max-w-xl">
            <form phx-change="search" phx-submit="search" id="section-search-form">
              <.search_input
                id="section-search"
                name="query"
                value={@search_query}
                placeholder="Search sections..."
                phx-debounce="300"
              />
            </form>
          </div>
          <.link navigate={~p"/admin/section/new"} class="gf-btn gf-btn-primary">
            New Section
          </.link>
        </div>

        <%!-- Info card --%>
        <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
          <p class="text-sm text-blue-800">
            <.icon name="ph-info" class="h-4 w-4 inline mr-1" />
            Sections group host plant species within a genus. They are primarily used for
            Quercus (oaks) to distinguish Red Oaks, White Oaks, etc.
          </p>
        </div>

        <%!-- Sections list table --%>
        <div class="bg-white shadow rounded-lg overflow-hidden">
          <table class="gf-table gf-table-dark">
            <thead>
              <tr>
                <th>Section</th>
                <th>Description</th>
                <th>Genus</th>
                <th>Species</th>
                <th class="text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={section <- @sections}>
                <td>
                  <.link
                    navigate={~p"/admin/section/#{section.id}"}
                    class="hover:underline font-medium"
                  >
                    <.taxon_name name={section.name} rank="section" />
                  </.link>
                </td>
                <td class="text-gray-500">
                  {section.description || "—"}
                </td>
                <td>
                  <%= if section.genus_name do %>
                    <.link navigate={~p"/genus/#{section.genus_name}"} class="hover:underline">
                      <.taxon_name name={section.genus_name} rank="genus" />
                    </.link>
                  <% else %>
                    <span class="text-gray-400">—</span>
                  <% end %>
                </td>
                <td class="text-center">
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                    {section.species_count}
                  </span>
                </td>
                <td class="text-right">
                  <.table_actions>
                    <.action_button
                      icon="ph-pencil-simple"
                      label="Edit"
                      navigate={~p"/admin/section/#{section.id}"}
                      variant="primary"
                    />
                    <.action_button
                      icon="ph-arrow-square-out"
                      label="View"
                      navigate={~p"/section/#{section.name}"}
                    />
                    <.action_button
                      icon="ph-trash"
                      label="Delete"
                      variant="danger"
                      phx-click="delete"
                      phx-value-id={section.id}
                      confirm="Are you sure? This will remove all species from this section."
                    />
                  </.table_actions>
                </td>
              </tr>
              <tr :if={@sections == []}>
                <td colspan="5" class="px-6 py-8 text-center text-gray-500">
                  No sections found. Try a different search term or create a new section.
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <p class="text-sm text-gray-500">
          Showing {length(@sections)} sections
        </p>
      </div>
    </Layouts.admin>
    """
  end
end
