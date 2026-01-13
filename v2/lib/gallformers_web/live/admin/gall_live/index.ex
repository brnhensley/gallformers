defmodule GallformersWeb.Admin.GallLive.Index do
  @moduledoc """
  Admin page for listing and searching galls.
  """
  use GallformersWeb, :live_view

  alias Gallformers.Species

  @impl true
  def mount(_params, session, socket) do
    current_user = session["current_user"]

    if connected?(socket), do: Species.subscribe()

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:page_title, "Galls")
      |> assign(:search_query, "")
      |> assign(:gall_list, list_galls(""))

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Galls")
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    gall_list = list_galls(query)
    {:noreply, assign(socket, gall_list: gall_list, search_query: query)}
  end

  @impl true
  def handle_info({event, _species}, socket)
      when event in [:species_created, :species_updated, :species_deleted] do
    gall_list = list_galls(socket.assigns.search_query)
    {:noreply, assign(socket, gall_list: gall_list)}
  end

  defp list_galls("") do
    Species.list_species_admin(100, 0)
    |> Enum.filter(&(&1.taxoncode == "gall"))
  end

  defp list_galls(query) do
    Species.search_species(query, 100)
    |> Enum.filter(&(&1.taxoncode == "gall"))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} page_title="Galls">
      <div class="space-y-6">
        <%!-- Header with search and new button --%>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div class="flex-1 max-w-xl">
            <form phx-change="search" phx-submit="search" id="gall-search-form">
              <.input
                type="text"
                name="query"
                value={@search_query}
                placeholder="Filter galls by name or alias..."
                phx-debounce="300"
              />
            </form>
          </div>
          <.link
            navigate={~p"/admin/galls/new"}
            class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm !text-white !no-underline bg-gf-maroon hover:bg-gf-maroon/90 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gf-maroon"
          >
            <.icon name="hero-plus" class="h-5 w-5 mr-2" /> New Gall
          </.link>
        </div>

        <%!-- Gall list table --%>
        <div class="bg-white shadow rounded-lg overflow-hidden">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-cadet-blue">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-white uppercase tracking-wider">
                  Name
                </th>
                <th class="px-6 py-3 text-center text-xs font-medium text-white uppercase tracking-wider w-32">
                  Data Complete
                </th>
                <th class="px-6 py-3 text-right text-xs font-medium text-white uppercase tracking-wider w-24">
                </th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <tr :for={gall <- @gall_list} class="hover:bg-gray-50">
                <td class="px-6 py-4 whitespace-nowrap">
                  <.link
                    navigate={~p"/admin/galls/#{gall.id}"}
                    class="text-gf-maroon hover:underline font-medium italic"
                  >
                    {gall.name}
                  </.link>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-center">
                  <%= if gall.datacomplete in [true, 1] do %>
                    <span class="text-green-600">
                      <.icon name="hero-check" class="size-5 inline-block" />
                    </span>
                  <% else %>
                    <span class="text-red-500">
                      <.icon name="hero-x-mark" class="size-5 inline-block" />
                    </span>
                  <% end %>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                  <.link
                    navigate={~p"/admin/galls/#{gall.id}"}
                    class="text-gf-maroon hover:text-gf-autumn mr-4"
                  >
                    Edit
                  </.link>
                  <.link navigate={~p"/gall/#{gall.id}"} class="text-gray-600 hover:text-gray-900">
                    View
                  </.link>
                </td>
              </tr>
              <tr :if={@gall_list == []}>
                <td colspan="3" class="px-6 py-8 text-center text-gray-500">
                  No galls found. Try a different search term.
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <p class="text-sm text-gray-500">
          Showing {@gall_list |> length()} galls
        </p>
      </div>
    </Layouts.admin>
    """
  end
end
