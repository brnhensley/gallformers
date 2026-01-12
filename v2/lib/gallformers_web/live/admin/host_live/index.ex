defmodule GallformersWeb.Admin.HostLive.Index do
  @moduledoc """
  Admin page for listing and searching host species.
  """
  use GallformersWeb, :live_view

  alias Gallformers.Hosts

  @impl true
  def mount(_params, session, socket) do
    current_user = session["current_user"]

    if connected?(socket), do: Hosts.subscribe()

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:page_title, "Hosts")
      |> assign(:search_query, "")
      |> assign(:hosts, list_hosts(""))

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Hosts")
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    hosts = list_hosts(query)
    {:noreply, assign(socket, hosts: hosts, search_query: query)}
  end

  @impl true
  def handle_info({event, _host}, socket)
      when event in [:host_created, :host_updated, :host_deleted] do
    hosts = list_hosts(socket.assigns.search_query)
    {:noreply, assign(socket, hosts: hosts)}
  end

  defp list_hosts(""), do: Hosts.list_hosts_paginated(100, 0)
  defp list_hosts(query), do: Hosts.search_hosts(query, 100)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} page_title="Hosts">
      <div class="space-y-6">
        <%!-- Header with search and new button --%>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div class="flex-1 max-w-lg">
            <form phx-change="search" phx-submit="search" id="host-search-form">
              <.input
                type="text"
                name="query"
                value={@search_query}
                placeholder="Search hosts by name..."
                phx-debounce="300"
              />
            </form>
          </div>
          <.link
            navigate={~p"/admin/hosts/new"}
            class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-gf-maroon hover:bg-gf-maroon/90"
          >
            <.icon name="hero-plus" class="h-5 w-5 mr-2" /> New Host
          </.link>
        </div>

        <%!-- Host list table --%>
        <div class="bg-white shadow rounded-lg overflow-hidden">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-cadet-blue">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-white uppercase tracking-wider">
                  Name
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
              <tr :for={host <- @hosts} class="hover:bg-gray-50">
                <td class="px-6 py-4 whitespace-nowrap">
                  <.link
                    navigate={~p"/admin/hosts/#{host.id}"}
                    class="text-gf-maroon hover:underline font-medium"
                  >
                    {host.name}
                  </.link>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <%= if host.datacomplete do %>
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
                    navigate={~p"/admin/hosts/#{host.id}"}
                    class="text-gf-maroon hover:text-gf-autumn mr-4"
                  >
                    Edit
                  </.link>
                  <.link navigate={~p"/host/#{host.id}"} class="text-gray-600 hover:text-gray-900">
                    View
                  </.link>
                </td>
              </tr>
              <tr :if={@hosts == []}>
                <td colspan="3" class="px-6 py-8 text-center text-gray-500">
                  No hosts found. Try a different search term.
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <p class="text-sm text-gray-500">
          Showing {@hosts |> length()} hosts
        </p>
      </div>
    </Layouts.admin>
    """
  end
end
