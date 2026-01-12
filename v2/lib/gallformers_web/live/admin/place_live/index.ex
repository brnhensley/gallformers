defmodule GallformersWeb.Admin.PlaceLive.Index do
  @moduledoc """
  Admin page for listing and managing geographic places.
  """
  use GallformersWeb, :live_view

  alias Gallformers.Places

  @impl true
  def mount(_params, session, socket) do
    current_user = session["current_user"]

    if connected?(socket), do: Places.subscribe()

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:page_title, "Places")
      |> assign(:search_query, "")
      |> load_places()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Places")
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    socket =
      socket
      |> assign(:search_query, query)
      |> load_places()

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    place = Places.get_place!(String.to_integer(id))

    case Places.delete_place(place) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Place deleted successfully")
         |> load_places()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete place")}
    end
  end

  @impl true
  def handle_info({event, _place}, socket)
      when event in [:place_created, :place_updated, :place_deleted] do
    {:noreply, load_places(socket)}
  end

  defp load_places(socket) do
    places =
      case socket.assigns.search_query do
        "" -> Places.list_all_places()
        query -> Places.search_places(query, 100)
      end

    assign(socket, :places, places)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} page_title="Places">
      <div class="space-y-6">
        <%!-- Info banner --%>
        <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
          <div class="flex">
            <.icon name="hero-information-circle" class="h-5 w-5 text-blue-400 mr-2 flex-shrink-0" />
            <div class="text-sm text-blue-700">
              <p>
                Places represent geographic locations (states, provinces) used for species range data.
                Currently supports US states and Canadian provinces.
                Range assignments are managed through the Host admin page.
              </p>
            </div>
          </div>
        </div>

        <%!-- Header with search and new button --%>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div class="flex-1 max-w-lg">
            <form phx-change="search" phx-submit="search" id="place-search-form">
              <.input
                type="text"
                name="query"
                value={@search_query}
                placeholder="Search places..."
                phx-debounce="300"
              />
            </form>
          </div>
          <.link
            navigate={~p"/admin/places/new"}
            class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-gf-maroon hover:bg-gf-maroon/90"
          >
            <.icon name="hero-plus" class="h-5 w-5 mr-2" /> New Place
          </.link>
        </div>

        <%!-- Place list table --%>
        <div class="bg-white shadow rounded-lg overflow-hidden">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-cadet-blue">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-white uppercase tracking-wider">
                  Name
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-white uppercase tracking-wider">
                  Code
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-white uppercase tracking-wider">
                  Type
                </th>
                <th class="px-6 py-3 text-right text-xs font-medium text-white uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <tr :for={place <- @places} class="hover:bg-gray-50">
                <td class="px-6 py-4 whitespace-nowrap">
                  <.link
                    navigate={~p"/admin/places/#{place.id}"}
                    class="text-gf-maroon hover:underline font-medium"
                  >
                    {place.name}
                  </.link>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                    {place.code}
                  </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {place.type}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                  <.link
                    navigate={~p"/admin/places/#{place.id}"}
                    class="text-gf-maroon hover:text-gf-autumn mr-4"
                  >
                    Edit
                  </.link>
                  <button
                    phx-click="delete"
                    phx-value-id={place.id}
                    data-confirm="Are you sure? This will remove all species range associations for this place."
                    class="text-red-600 hover:text-red-900"
                  >
                    Delete
                  </button>
                </td>
              </tr>
              <tr :if={@places == []}>
                <td colspan="4" class="px-6 py-8 text-center text-gray-500">
                  No places found. Try a different search term.
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <p class="text-sm text-gray-500">
          Showing {@places |> length()} places
        </p>
      </div>
    </Layouts.admin>
    """
  end
end
