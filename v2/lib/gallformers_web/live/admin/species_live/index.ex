defmodule GallformersWeb.Admin.SpeciesLive.Index do
  @moduledoc """
  Admin page for listing and searching species.
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
      |> assign(:page_title, "Species")
      |> assign(:search_query, "")
      |> assign(:filter_type, "all")
      |> assign(:species_list, list_species("", "all"))

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Species")
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    species_list = list_species(query, socket.assigns.filter_type)
    {:noreply, assign(socket, species_list: species_list, search_query: query)}
  end

  @impl true
  def handle_event("filter", %{"type" => type}, socket) do
    species_list = list_species(socket.assigns.search_query, type)
    {:noreply, assign(socket, species_list: species_list, filter_type: type)}
  end

  @impl true
  def handle_info({event, _species}, socket)
      when event in [:species_created, :species_updated, :species_deleted] do
    species_list = list_species(socket.assigns.search_query, socket.assigns.filter_type)
    {:noreply, assign(socket, species_list: species_list)}
  end

  defp list_species("", "all"), do: Species.list_species_admin(100, 0)

  defp list_species("", type) do
    Species.list_species_admin(100, 0)
    |> Enum.filter(&(&1.taxoncode == type))
  end

  defp list_species(query, "all"), do: Species.search_species(query, 100)

  defp list_species(query, type) do
    Species.search_species(query, 100)
    |> Enum.filter(&(&1.taxoncode == type))
  end

  defp taxoncode_label("gall"), do: "Gall"
  defp taxoncode_label("plant"), do: "Host"
  defp taxoncode_label("undetermined"), do: "Undetermined"
  defp taxoncode_label(_), do: "Unknown"

  defp taxoncode_badge_class("gall"), do: "bg-amber-100 text-amber-800"
  defp taxoncode_badge_class("plant"), do: "bg-green-100 text-green-800"
  defp taxoncode_badge_class("undetermined"), do: "bg-gray-100 text-gray-800"
  defp taxoncode_badge_class(_), do: "bg-gray-100 text-gray-800"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} page_title="Species">
      <div class="space-y-6">
        <%!-- Header with search, filter and new button --%>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div class="flex-1 flex flex-col sm:flex-row gap-4 max-w-2xl">
            <div class="flex-1">
              <form phx-change="search" phx-submit="search" id="species-search-form">
                <.input
                  type="text"
                  name="query"
                  value={@search_query}
                  placeholder="Search species by name or alias..."
                  phx-debounce="300"
                />
              </form>
            </div>
            <div class="w-40">
              <form phx-change="filter" id="species-filter-form">
                <.input
                  type="select"
                  name="type"
                  value={@filter_type}
                  options={[
                    {"All Types", "all"},
                    {"Galls", "gall"},
                    {"Hosts", "plant"},
                    {"Undetermined", "undetermined"}
                  ]}
                />
              </form>
            </div>
          </div>
          <.link
            navigate={~p"/admin/species/new"}
            class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-gf-maroon hover:bg-gf-maroon/90"
          >
            <.icon name="hero-plus" class="h-5 w-5 mr-2" /> New Species
          </.link>
        </div>

        <%!-- Species list table --%>
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
                  Abundance
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-white uppercase tracking-wider">
                  Data Complete
                </th>
                <th class="px-6 py-3 text-right text-xs font-medium text-white uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <tr :for={species <- @species_list} class="hover:bg-gray-50">
                <td class="px-6 py-4 whitespace-nowrap">
                  <.link
                    navigate={~p"/admin/species/#{species.id}"}
                    class="text-gf-maroon hover:underline font-medium italic"
                  >
                    {species.name}
                  </.link>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class={[
                    "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
                    taxoncode_badge_class(species.taxoncode)
                  ]}>
                    {taxoncode_label(species.taxoncode)}
                  </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-gray-500">
                  {species.abundance_name || "—"}
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <%= if species.datacomplete do %>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                      Yes
                    </span>
                  <% else %>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                      No
                    </span>
                  <% end %>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                  <.link
                    navigate={~p"/admin/species/#{species.id}"}
                    class="text-gf-maroon hover:text-gf-autumn mr-4"
                  >
                    Edit
                  </.link>
                  <%= if species.taxoncode == "gall" do %>
                    <.link
                      navigate={~p"/gall/#{species.id}"}
                      class="text-gray-600 hover:text-gray-900"
                    >
                      View
                    </.link>
                  <% else %>
                    <.link
                      navigate={~p"/host/#{species.id}"}
                      class="text-gray-600 hover:text-gray-900"
                    >
                      View
                    </.link>
                  <% end %>
                </td>
              </tr>
              <tr :if={@species_list == []}>
                <td colspan="5" class="px-6 py-8 text-center text-gray-500">
                  No species found. Try a different search term or filter.
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <p class="text-sm text-gray-500">
          Showing {@species_list |> length()} species
        </p>
      </div>
    </Layouts.admin>
    """
  end
end
