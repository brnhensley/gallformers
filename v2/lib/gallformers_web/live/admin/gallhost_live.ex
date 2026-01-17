defmodule GallformersWeb.Admin.GallhostLive do
  @moduledoc """
  Admin tool for managing gall-host mappings and gall range exclusions.

  This is a dedicated page for the complex workflow of:
  1. Selecting a gall
  2. Managing which hosts it's associated with
  3. Managing which places are excluded from its range

  The gall's effective range = (union of all host places) - (excluded places)
  """
  use GallformersWeb, :live_view

  alias Gallformers.Hosts
  alias Gallformers.Places
  alias Gallformers.Species

  @impl true
  def mount(_params, session, socket) do
    current_user = session["current_user"]
    all_places = Places.list_places()

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:page_title, "Gall-Host Mappings")
      |> assign(:all_places, all_places)
      # Gall selection state
      |> assign(:gall_search_query, "")
      |> assign(:gall_search_results, [])
      |> assign(:selected_gall, nil)
      # Host management state
      |> assign(:hosts, [])
      |> assign(:host_search_query, "")
      |> assign(:host_search_results, [])
      |> assign(:host_dropdown_open, false)
      # Range state
      |> assign(:host_places, [])
      |> assign(:excluded_places, [])
      |> assign(:in_range, [])

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    # Support ?id=123 to pre-select a gall
    case Map.get(params, "id") do
      nil ->
        {:noreply, socket}

      id_str ->
        case Integer.parse(id_str) do
          {id, ""} -> {:noreply, load_gall(socket, id)}
          _ -> {:noreply, put_flash(socket, :error, "Invalid gall ID in URL")}
        end
    end
  end

  # ============================================
  # Gall Selection Events
  # ============================================

  @impl true
  def handle_event("search_galls", %{"value" => query}, socket) do
    results =
      if String.length(query) >= 2 do
        Species.search_species_by_name(query, "gall", 10)
      else
        []
      end

    {:noreply, assign(socket, gall_search_query: query, gall_search_results: results)}
  end

  @impl true
  def handle_event("select_gall", %{"id" => gall_id_str}, socket) do
    case Integer.parse(gall_id_str) do
      {gall_id, ""} ->
        socket =
          socket
          |> assign(:gall_search_query, "")
          |> assign(:gall_search_results, [])
          |> load_gall(gall_id)

        {:noreply, socket}

      _ ->
        {:noreply, put_flash(socket, :error, "Invalid gall ID")}
    end
  end

  @impl true
  def handle_event("clear_gall", _params, socket) do
    socket =
      socket
      |> assign(:selected_gall, nil)
      |> assign(:hosts, [])
      |> assign_range_data([], [])

    {:noreply, socket}
  end

  # ============================================
  # Host Management Events
  # ============================================

  @impl true
  def handle_event("search_hosts", %{"value" => query}, socket) do
    results =
      if String.length(query) >= 2 do
        Species.search_species_by_name(query, "plant", 10)
      else
        []
      end

    {:noreply,
     socket
     |> assign(:host_search_query, query)
     |> assign(:host_search_results, results)
     |> assign(:host_dropdown_open, results != [])}
  end

  @impl true
  def handle_event("open_host_dropdown", _params, socket) do
    {:noreply, assign(socket, :host_dropdown_open, true)}
  end

  @impl true
  def handle_event("close_host_dropdown", _params, socket) do
    {:noreply, assign(socket, :host_dropdown_open, false)}
  end

  @impl true
  def handle_event("add_host", %{"id" => host_id_str}, socket) do
    gall = socket.assigns.selected_gall

    with %{id: gall_id} <- gall,
         {host_id, ""} <- Integer.parse(host_id_str) do
      case Species.add_host_to_species(gall_id, host_id) do
        {:ok, _} ->
          socket =
            socket
            |> reload_hosts_and_places()
            |> assign(:host_search_query, "")
            |> assign(:host_search_results, [])
            |> assign(:host_dropdown_open, false)
            |> put_flash(:info, "Host added")

          {:noreply, socket}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to add host (may already be associated)")}
      end
    else
      nil -> {:noreply, put_flash(socket, :error, "Select a gall first")}
      _ -> {:noreply, put_flash(socket, :error, "Invalid host ID")}
    end
  end

  @impl true
  def handle_event("remove_host", %{"id" => id}, socket) do
    case Integer.parse(id) do
      {relation_id, ""} ->
        Species.remove_host_from_species(relation_id)

        socket =
          socket
          |> reload_hosts_and_places()
          |> put_flash(:info, "Host removed")

        {:noreply, socket}

      _ ->
        {:noreply, put_flash(socket, :error, "Invalid relation ID")}
    end
  end

  # ============================================
  # Range/Exclusion Events
  # ============================================

  @impl true
  def handle_event("toggle_region", %{"code" => code}, socket) do
    with %{id: gall_id} <- socket.assigns.selected_gall,
         %{id: place_id} <- Enum.find(socket.assigns.all_places, &(&1.code == code)),
         true <- code in socket.assigns.host_places do
      Hosts.toggle_exclusion_for_gall(gall_id, place_id)
      excluded_places = Hosts.get_excluded_places_for_gall(gall_id)
      {:noreply, assign_range_data(socket, socket.assigns.host_places, excluded_places)}
    else
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_all_places", _params, socket) do
    gall = socket.assigns.selected_gall

    if gall do
      # Select all = remove all exclusions (all host places are in range)
      Hosts.set_range_exclusions_for_gall(gall.id, [])
      {:noreply, assign_range_data(socket, socket.assigns.host_places, [])}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("deselect_all_places", _params, socket) do
    gall = socket.assigns.selected_gall

    if gall do
      # Deselect all = exclude all host places
      host_place_ids = Hosts.get_host_place_ids_for_gall(gall.id)
      Hosts.set_range_exclusions_for_gall(gall.id, host_place_ids)
      excluded_places = Hosts.get_excluded_places_for_gall(gall.id)
      {:noreply, assign_range_data(socket, socket.assigns.host_places, excluded_places)}
    else
      {:noreply, socket}
    end
  end

  # ============================================
  # Helper Functions
  # ============================================

  defp load_gall(socket, gall_id) do
    case Species.get_species(gall_id) do
      nil ->
        put_flash(socket, :error, "Gall not found")

      gall ->
        if gall.taxoncode != "gall" do
          put_flash(socket, :error, "Selected species is not a gall")
        else
          hosts = Hosts.get_hosts_for_gall(gall_id)
          host_places = Hosts.get_places_for_gall(gall_id)
          excluded_places = Hosts.get_excluded_places_for_gall(gall_id)

          socket
          |> assign(:selected_gall, gall)
          |> assign(:hosts, hosts)
          |> assign_range_data(host_places, excluded_places)
          |> assign(:page_title, "Gall-Host Mappings - #{gall.name}")
        end
    end
  end

  defp reload_hosts_and_places(socket) do
    gall = socket.assigns.selected_gall

    if gall do
      hosts = Hosts.get_hosts_for_gall(gall.id)
      host_places = Hosts.get_places_for_gall(gall.id)

      # Clean up exclusions that no longer apply (host was removed)
      current_exclusions = Hosts.get_excluded_places_for_gall(gall.id)
      valid_exclusions = Enum.filter(current_exclusions, &(&1 in host_places))

      # If exclusions changed, update the database
      if length(valid_exclusions) != length(current_exclusions) do
        valid_place_ids =
          socket.assigns.all_places
          |> Enum.filter(&(&1.code in valid_exclusions))
          |> Enum.map(& &1.id)

        Hosts.set_range_exclusions_for_gall(gall.id, valid_place_ids)
      end

      socket
      |> assign(:hosts, hosts)
      |> assign_range_data(host_places, valid_exclusions)
    else
      socket
    end
  end

  # Assigns host_places, excluded_places, and computed in_range together
  defp assign_range_data(socket, host_places, excluded_places) do
    in_range = Enum.reject(host_places, &(&1 in excluded_places))

    socket
    |> assign(:host_places, host_places)
    |> assign(:excluded_places, excluded_places)
    |> assign(:in_range, in_range)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} page_title={@page_title}>
      <div class="max-w-7xl mx-auto">
        <div class="mb-4">
          <.link navigate={~p"/admin"} class="text-gf-maroon hover:underline text-sm">
            &larr; Back to Admin
          </.link>
        </div>

        <div class="bg-white border border-gray-200 rounded shadow-sm">
          <div class="px-4 py-3 border-b border-gray-200 bg-gray-50">
            <h4 class="text-lg font-semibold text-gf-maroon">Gall - Host Mappings</h4>
          </div>

          <div class="p-4">
            <%!-- Instructions --%>
            <p class="text-sm text-gray-600 mb-4">
              First select a gall. If any mappings to hosts already exist they will show up in the Host field.
              Then you can edit these mappings (add or delete).
            </p>
            <p class="text-sm text-gray-600 mb-4">
              At least one host species must exist before mapping.
              <.link navigate={~p"/admin/hosts"} class="text-gf-maroon hover:underline">
                Go add one
              </.link>
              now if you need to.
            </p>

            <%!-- Gall Selector --%>
            <div class="mb-4">
              <.typeahead
                id="gall-picker"
                label="Gall:"
                placeholder="Search for a gall..."
                query={@gall_search_query}
                results={@gall_search_results}
                selected={@selected_gall}
                search_event="search_galls"
                select_event="select_gall"
                clear_event="clear_gall"
                display_fn={& &1.name}
              >
                <:result :let={gall}>
                  <span class="italic">{gall.name}</span>
                </:result>
              </.typeahead>
            </div>

            <%!-- Bidirectional Arrow --%>
            <div class="flex justify-center my-2">
              <span class="text-2xl text-gray-400">⇅</span>
            </div>

            <%!-- Hosts Multi-select --%>
            <div class="mb-4">
              <%= if @selected_gall do %>
                <.multi_select_dropdown
                  id="host-picker"
                  label="Hosts:"
                  type={:hosts}
                  search_results={@host_search_results}
                  selected={@hosts}
                  search_query={@host_search_query}
                  dropdown_open={@host_dropdown_open}
                  item_id={:host_relation_id}
                  result_id={:id}
                  selected_match_id={:host_species_id}
                  item_label={:host_name}
                  result_label={:name}
                  placeholder={if @hosts == [], do: "Search hosts...", else: "Add more..."}
                  on_search="search_hosts"
                  on_add="add_host"
                  on_remove="remove_host"
                  on_open="open_host_dropdown"
                  on_close="close_host_dropdown"
                  size="md"
                />
                <%= if @hosts == [] do %>
                  <p class="text-red-600 text-xs mt-1">
                    You must map this gall to at least one host.
                  </p>
                <% end %>
              <% else %>
                <label class="block text-sm font-medium text-gray-700 mb-1">Hosts:</label>
                <div class="flex flex-wrap gap-1 p-2 border border-gray-200 bg-gray-50 rounded min-h-[42px]">
                  <span class="text-gray-400 text-sm">Select a gall first</span>
                </div>
              <% end %>
            </div>

            <%!-- Range Section --%>
            <div class="mb-4">
              <div class="flex items-center gap-2 mb-1">
                <label class="text-sm font-medium text-gray-700">Range:</label>
                <span
                  class="text-gray-400 cursor-help"
                  title="By default the range for a gall is the union of all places that the selected Hosts occur in. Click on places to exclude them from the gall's range. Do not exclude places based solely on a lack of observations."
                >
                  <.icon name="ph-question" class="h-4 w-4" />
                </span>
              </div>

              <div class="border border-gray-300 rounded">
                <div class="grid grid-cols-6 gap-2 p-3">
                  <%!-- Legend and Actions --%>
                  <div class="col-span-1">
                    <div class="text-sm font-medium text-gray-700 mb-2">Legend:</div>
                    <div class="space-y-1 mb-4">
                      <div class="flex items-center gap-2">
                        <div
                          class="w-4 h-4 rounded border border-gray-400"
                          style="background-color: ForestGreen;"
                        >
                        </div>
                        <span class="text-xs text-gray-600">Gall & Host</span>
                      </div>
                      <div class="flex items-center gap-2">
                        <div
                          class="w-4 h-4 rounded border border-gray-400"
                          style="background-color: LightCoral;"
                        >
                        </div>
                        <span class="text-xs text-gray-600">Host Only</span>
                      </div>
                      <div class="flex items-center gap-2">
                        <div class="w-4 h-4 rounded border border-gray-300 bg-white"></div>
                        <span class="text-xs text-gray-600">Neither</span>
                      </div>
                    </div>

                    <div class="text-sm font-medium text-gray-700 mb-2">Map Actions:</div>
                    <div class="space-y-2">
                      <button
                        type="button"
                        phx-click="select_all_places"
                        disabled={@selected_gall == nil}
                        class={[
                          "block w-full px-2 py-1 text-xs border border-gray-300 rounded",
                          if(@selected_gall,
                            do: "bg-gray-100 hover:bg-gray-200",
                            else: "bg-gray-50 text-gray-400 cursor-not-allowed"
                          )
                        ]}
                      >
                        Select All
                      </button>
                      <button
                        type="button"
                        phx-click="deselect_all_places"
                        disabled={@selected_gall == nil}
                        class={[
                          "block w-full px-2 py-1 text-xs border border-gray-300 rounded",
                          if(@selected_gall,
                            do: "bg-gray-100 hover:bg-gray-200",
                            else: "bg-gray-50 text-gray-400 cursor-not-allowed"
                          )
                        ]}
                      >
                        De-select All
                      </button>
                    </div>
                  </div>

                  <%!-- Map --%>
                  <div class="col-span-5">
                    <%= if @selected_gall do %>
                      <div
                        id="gallhost-range-map"
                        phx-hook="RangeMap"
                        phx-update="ignore"
                        data-in-range={Jason.encode!(@in_range)}
                        data-excluded-range={Jason.encode!(@excluded_places)}
                        data-editable="true"
                        class="border border-gray-300 rounded bg-gray-50 min-h-[350px]"
                      >
                        <div class="flex items-center justify-center h-64 text-gray-400">
                          Loading map...
                        </div>
                      </div>
                    <% else %>
                      <div class="border border-gray-300 rounded bg-gray-100 min-h-[350px] flex items-center justify-center">
                        <p class="text-gray-500 text-sm">Select a gall to see its range</p>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
            </div>

            <%!-- Range Info --%>
            <%= if @selected_gall do %>
              <div class="text-sm text-gray-600 mb-4">
                <span class="font-medium">Range summary:</span>
                {length(@in_range)} places in range, {length(@excluded_places)} excluded, {length(
                  @host_places
                )} total from hosts
              </div>
            <% end %>

            <%!-- Actions --%>
            <div class="flex justify-between items-center pt-3 border-t border-gray-200">
              <div>
                <%= if @selected_gall do %>
                  <.link
                    navigate={~p"/gall/#{@selected_gall.id}"}
                    class="text-sm text-gf-maroon hover:underline"
                  >
                    View public page
                  </.link>
                  <span class="mx-2 text-gray-300">|</span>
                  <.link
                    navigate={~p"/admin/galls/#{@selected_gall.id}"}
                    class="text-sm text-gf-maroon hover:underline"
                  >
                    Edit gall details
                  </.link>
                <% end %>
              </div>
              <div>
                <.link
                  navigate={~p"/admin"}
                  class="px-4 py-2 text-sm text-gray-600 hover:text-gray-800"
                >
                  Done
                </.link>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end
end
