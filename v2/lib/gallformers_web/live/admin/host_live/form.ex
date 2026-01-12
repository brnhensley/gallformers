defmodule GallformersWeb.Admin.HostLive.Form do
  @moduledoc """
  Admin form for creating and editing host species.

  Note: Host editing is complex because hosts are species in the species table
  with taxoncode="plant". Full CRUD operations require Species context.
  This form provides read and basic display for now.
  """
  use GallformersWeb, :live_view

  alias Gallformers.Hosts

  @impl true
  def mount(_params, session, socket) do
    current_user = session["current_user"]

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:page_title, "Host")

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Host")
    |> assign(:host, nil)
    |> assign(:mode, :new)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    host = Hosts.get_host_for_edit(String.to_integer(id))

    if host do
      socket
      |> assign(:page_title, "Edit Host - #{host.name}")
      |> assign(:host, host)
      |> assign(:mode, :edit)
    else
      socket
      |> put_flash(:error, "Host not found")
      |> push_navigate(to: ~p"/admin/hosts")
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} page_title={@page_title}>
      <div class="max-w-4xl">
        <%!-- Back link --%>
        <div class="mb-6">
          <.link navigate={~p"/admin/hosts"} class="text-gf-maroon hover:underline">
            <.icon name="hero-arrow-left" class="h-4 w-4 inline" /> Back to Hosts
          </.link>
        </div>

        <%= if @mode == :new do %>
          <.new_host_form />
        <% else %>
          <.edit_host_display host={@host} />
        <% end %>
      </div>
    </Layouts.admin>
    """
  end

  defp new_host_form(assigns) do
    ~H"""
    <div class="bg-white shadow rounded-lg p-6">
      <h2 class="text-xl font-semibold text-gf-maroon mb-4">Create New Host</h2>
      <div class="bg-yellow-50 border border-yellow-200 rounded-md p-4">
        <div class="flex">
          <.icon name="hero-exclamation-triangle" class="h-5 w-5 text-yellow-400 mr-2" />
          <div class="text-sm text-yellow-700">
            <p class="font-medium">Feature in development</p>
            <p class="mt-1">
              Creating new hosts requires setting up the species entry with taxonomy linkages.
              This functionality will be added in a future update.
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp edit_host_display(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Basic Info Card --%>
      <div class="bg-white shadow rounded-lg overflow-hidden">
        <div class="px-6 py-4 border-b border-gray-200 bg-gray-50">
          <h2 class="text-xl font-semibold text-gf-maroon">Host Information</h2>
        </div>
        <div class="p-6 space-y-4">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700">Name</label>
              <p class="mt-1 text-lg font-medium text-gray-900 italic">{@host.name}</p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700">Data Complete</label>
              <p class="mt-1">
                <%= if @host.datacomplete do %>
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                    Yes
                  </span>
                <% else %>
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                    No
                  </span>
                <% end %>
              </p>
            </div>
          </div>

          <%= if @host.abundance_name do %>
            <div>
              <label class="block text-sm font-medium text-gray-700">Abundance</label>
              <p class="mt-1 text-gray-900">{@host.abundance_name}</p>
            </div>
          <% end %>
        </div>
      </div>

      <%!-- Taxonomy Card --%>
      <%= if @host.taxonomy do %>
        <div class="bg-white shadow rounded-lg overflow-hidden">
          <div class="px-6 py-4 border-b border-gray-200 bg-gray-50">
            <h2 class="text-xl font-semibold text-gf-maroon">Taxonomy</h2>
          </div>
          <div class="p-6">
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700">Family</label>
                <p class="mt-1 text-gray-900">{@host.taxonomy.family || "—"}</p>
              </div>
              <%= if @host.taxonomy.section do %>
                <div>
                  <label class="block text-sm font-medium text-gray-700">Section</label>
                  <p class="mt-1 text-gray-900">{@host.taxonomy.section}</p>
                </div>
              <% end %>
              <div>
                <label class="block text-sm font-medium text-gray-700">Genus</label>
                <p class="mt-1 text-gray-900 italic">{@host.taxonomy.genus || "—"}</p>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <%!-- Range Card --%>
      <%= if @host.places && @host.places != [] do %>
        <div class="bg-white shadow rounded-lg overflow-hidden">
          <div class="px-6 py-4 border-b border-gray-200 bg-gray-50">
            <h2 class="text-xl font-semibold text-gf-maroon">Range</h2>
          </div>
          <div class="p-6">
            <div class="flex flex-wrap gap-2">
              <span
                :for={place <- @host.places}
                class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800"
              >
                {place}
              </span>
            </div>
          </div>
        </div>
      <% end %>

      <%!-- Aliases Card --%>
      <%= if @host.aliases && @host.aliases != [] do %>
        <div class="bg-white shadow rounded-lg overflow-hidden">
          <div class="px-6 py-4 border-b border-gray-200 bg-gray-50">
            <h2 class="text-xl font-semibold text-gf-maroon">Aliases</h2>
          </div>
          <div class="p-6">
            <ul class="list-disc list-inside space-y-1">
              <li :for={alias_name <- @host.aliases} class="text-gray-900 italic">
                {alias_name}
              </li>
            </ul>
          </div>
        </div>
      <% end %>

      <%!-- Actions --%>
      <div class="flex justify-between items-center">
        <.link navigate={~p"/host/#{@host.id}"} class="text-gf-maroon hover:underline">
          View public page
        </.link>
        <div class="bg-yellow-50 border border-yellow-200 rounded-md p-3">
          <p class="text-sm text-yellow-700">
            <.icon name="hero-information-circle" class="h-4 w-4 inline mr-1" />
            Full editing functionality coming soon
          </p>
        </div>
      </div>
    </div>
    """
  end
end
