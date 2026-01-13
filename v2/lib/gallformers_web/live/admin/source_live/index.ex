defmodule GallformersWeb.Admin.SourceLive.Index do
  @moduledoc """
  Admin page for listing and searching scientific sources/references.
  """
  use GallformersWeb, :live_view

  alias Gallformers.Sources

  @impl true
  def mount(_params, session, socket) do
    current_user = session["current_user"]

    if connected?(socket), do: Sources.subscribe()

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:page_title, "Sources")
      |> assign(:search_query, "")
      |> load_sources()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Sources")
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    socket =
      socket
      |> assign(:search_query, query)
      |> load_sources()

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    source = Sources.get_source!(String.to_integer(id))

    case Sources.delete_source(source) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Source deleted successfully")
         |> load_sources()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete source")}
    end
  end

  @impl true
  def handle_info({event, _source}, socket)
      when event in [:source_created, :source_updated, :source_deleted] do
    {:noreply, load_sources(socket)}
  end

  defp load_sources(socket) do
    sources =
      case socket.assigns.search_query do
        "" -> Sources.list_sources_paginated(100, 0)
        query -> Sources.search_sources(query)
      end

    assign(socket, :sources, sources)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} page_title="Sources">
      <div class="space-y-6">
        <%!-- Header with search and new button --%>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div class="flex-1 max-w-lg">
            <form phx-change="search" phx-submit="search" id="source-search-form">
              <.input
                type="text"
                name="query"
                value={@search_query}
                placeholder="Search sources by title or author..."
                phx-debounce="300"
              />
            </form>
          </div>
          <.link
            navigate={~p"/admin/sources/new"}
            class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm !text-white !no-underline bg-gf-maroon hover:bg-gf-maroon/90 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gf-maroon"
          >
            <.icon name="hero-plus" class="h-5 w-5 mr-2" /> New Source
          </.link>
        </div>

        <%!-- Source list table --%>
        <div class="bg-white shadow rounded-lg overflow-hidden">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-cadet-blue">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-white uppercase tracking-wider">
                  Title
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-white uppercase tracking-wider">
                  Author
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-white uppercase tracking-wider">
                  Year
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-white uppercase tracking-wider">
                  Complete
                </th>
                <th class="px-6 py-3 text-right text-xs font-medium text-white uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <tr :for={source <- @sources} class="hover:bg-gray-50">
                <td class="px-6 py-4">
                  <.link
                    navigate={~p"/admin/sources/#{source.id}"}
                    class="text-gf-maroon hover:underline font-medium"
                  >
                    {truncate(source.title, 60)}
                  </.link>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {truncate(source.author, 30)}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {source.pubyear}
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <%= if source.datacomplete do %>
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
                    navigate={~p"/admin/sources/#{source.id}"}
                    class="text-gf-maroon hover:text-gf-autumn mr-4"
                  >
                    Edit
                  </.link>
                  <button
                    phx-click="delete"
                    phx-value-id={source.id}
                    data-confirm="Are you sure? This will remove all species associations."
                    class="text-red-600 hover:text-red-900"
                  >
                    Delete
                  </button>
                </td>
              </tr>
              <tr :if={@sources == []}>
                <td colspan="5" class="px-6 py-8 text-center text-gray-500">
                  No sources found. Try a different search term.
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <p class="text-sm text-gray-500">
          Showing {@sources |> length()} sources
        </p>
      </div>
    </Layouts.admin>
    """
  end

  defp truncate(nil, _), do: ""

  defp truncate(string, max_length) do
    if String.length(string) > max_length do
      String.slice(string, 0, max_length) <> "..."
    else
      string
    end
  end
end
