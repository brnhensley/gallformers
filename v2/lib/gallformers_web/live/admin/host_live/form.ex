defmodule GallformersWeb.Admin.HostLive.Form do
  @moduledoc """
  Admin form for creating and editing host species.
  Layout mirrors V1 host admin for consistency.
  """
  use GallformersWeb, :live_view

  alias Gallformers.Hosts
  alias Gallformers.Places
  alias Gallformers.Species
  alias Gallformers.Species.Species, as: SpeciesSchema
  alias Gallformers.Taxonomy

  @impl true
  def mount(_params, session, socket) do
    current_user = session["current_user"]
    abundances = Species.list_abundances()
    all_places = Places.list_places()

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:page_title, "Host")
      |> assign(:abundances, abundances)
      |> assign(:all_places, all_places)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    host = %SpeciesSchema{taxoncode: "plant"}
    changeset = Hosts.change_host(host)

    socket
    |> assign(:page_title, "New Host")
    |> assign(:host, host)
    |> assign(:form, to_form(changeset))
    |> assign(:mode, :new)
    |> assign(:aliases, [])
    |> assign(:places, [])
    |> assign(:taxonomy, nil)
    |> assign(:new_alias_name, "")
    |> assign(:new_alias_type, "common name")
    # Rename modal state
    |> assign(:show_rename_modal, false)
    |> assign(:rename_value, "")
    |> assign(:add_alias_on_rename, false)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    host_id = String.to_integer(id)

    case Hosts.get_host_species(host_id) do
      nil ->
        socket
        |> put_flash(:error, "Host not found")
        |> push_navigate(to: ~p"/admin/hosts")

      host ->
        if host.taxoncode != "plant" do
          socket
          |> put_flash(:error, "This is not a host. Use the Gall admin for gall species.")
          |> push_navigate(to: ~p"/admin/hosts")
        else
          changeset = Hosts.change_host(host)
          aliases = Hosts.get_aliases_for_host_full(host_id)
          places = Hosts.get_places_for_host(host_id)
          taxonomy = Taxonomy.get_taxonomy_for_species(host_id)

          socket
          |> assign(:page_title, "Edit Host - #{host.name}")
          |> assign(:host, host)
          |> assign(:form, to_form(changeset))
          |> assign(:mode, :edit)
          |> assign(:aliases, aliases)
          |> assign(:places, places)
          |> assign(:taxonomy, taxonomy)
          |> assign(:new_alias_name, "")
          |> assign(:new_alias_type, "common name")
          # Rename modal state
          |> assign(:show_rename_modal, false)
          |> assign(:rename_value, host.name)
          |> assign(:add_alias_on_rename, false)
        end
    end
  end

  # Event handlers

  @impl true
  def handle_event("validate", %{"species" => params}, socket) do
    changeset =
      socket.assigns.host
      |> Hosts.change_host(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"species" => params}, socket) do
    params = Map.put(params, "taxoncode", "plant")
    save_host(socket, socket.assigns.mode, params)
  end

  # Alias events

  @impl true
  def handle_event("update_new_alias", %{"name" => name, "type" => type}, socket) do
    {:noreply, assign(socket, new_alias_name: name, new_alias_type: type)}
  end

  @impl true
  def handle_event("add_alias", _params, socket) do
    name = String.trim(socket.assigns.new_alias_name)
    type = socket.assigns.new_alias_type

    if name == "" do
      {:noreply, put_flash(socket, :error, "Alias name cannot be empty")}
    else
      case Hosts.create_alias_for_host(socket.assigns.host.id, %{name: name, type: type}) do
        {:ok, _alias} ->
          aliases = Hosts.get_aliases_for_host_full(socket.assigns.host.id)

          {:noreply,
           socket
           |> assign(:aliases, aliases)
           |> assign(:new_alias_name, "")
           |> put_flash(:info, "Alias added")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to add alias")}
      end
    end
  end

  @impl true
  def handle_event("remove_alias", %{"alias-id" => alias_id}, socket) do
    Hosts.remove_alias_from_host(socket.assigns.host.id, String.to_integer(alias_id))
    aliases = Hosts.get_aliases_for_host_full(socket.assigns.host.id)

    {:noreply,
     socket
     |> assign(:aliases, aliases)
     |> put_flash(:info, "Alias removed")}
  end

  # Range/Place events

  @impl true
  def handle_event("toggle_region", %{"code" => code}, socket) do
    # Find the place by code
    place = Enum.find(socket.assigns.all_places, &(&1.code == code))

    if place && socket.assigns.mode == :edit do
      Hosts.toggle_place_for_host(socket.assigns.host.id, place.id)
      places = Hosts.get_places_for_host(socket.assigns.host.id)
      {:noreply, assign(socket, :places, places)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_all_places", _params, socket) do
    if socket.assigns.mode == :edit do
      place_ids = Enum.map(socket.assigns.all_places, & &1.id)
      Hosts.update_host_places(socket.assigns.host.id, place_ids)
      places = Hosts.get_places_for_host(socket.assigns.host.id)
      {:noreply, assign(socket, :places, places)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("deselect_all_places", _params, socket) do
    if socket.assigns.mode == :edit do
      Hosts.update_host_places(socket.assigns.host.id, [])
      {:noreply, assign(socket, :places, [])}
    else
      {:noreply, socket}
    end
  end

  # Rename modal events

  @impl true
  def handle_event("open_rename_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_rename_modal, true)
     |> assign(:rename_value, socket.assigns.host.name)
     |> assign(:add_alias_on_rename, false)}
  end

  @impl true
  def handle_event("close_rename_modal", _params, socket) do
    {:noreply, assign(socket, :show_rename_modal, false)}
  end

  @impl true
  def handle_event("update_rename_value", %{"value" => value}, socket) do
    {:noreply, assign(socket, :rename_value, value)}
  end

  @impl true
  def handle_event("toggle_add_alias_on_rename", _params, socket) do
    {:noreply, assign(socket, :add_alias_on_rename, !socket.assigns.add_alias_on_rename)}
  end

  @impl true
  def handle_event("do_rename", _params, socket) do
    new_name = String.trim(socket.assigns.rename_value)
    old_name = socket.assigns.host.name

    cond do
      new_name == "" ->
        {:noreply, put_flash(socket, :error, "Name cannot be empty")}

      new_name == old_name ->
        {:noreply, assign(socket, :show_rename_modal, false)}

      not valid_species_name?(new_name) ->
        {:noreply, put_flash(socket, :error, "Name must be a valid species name (Genus species)")}

      true ->
        case Hosts.rename_host(
               socket.assigns.host.id,
               new_name,
               socket.assigns.add_alias_on_rename
             ) do
          {:ok, updated_host} ->
            # Reload aliases if we added one
            aliases =
              if socket.assigns.add_alias_on_rename do
                Hosts.get_aliases_for_host_full(socket.assigns.host.id)
              else
                socket.assigns.aliases
              end

            {:noreply,
             socket
             |> assign(:host, updated_host)
             |> assign(:aliases, aliases)
             |> assign(:show_rename_modal, false)
             |> assign(:page_title, "Edit Host - #{new_name}")
             |> put_flash(:info, "Host renamed successfully")}

          {:error, :name_exists} ->
            {:noreply, put_flash(socket, :error, "That name is already in use")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to rename host")}
        end
    end
  end

  # Basic validation for species name (Genus species format)
  defp valid_species_name?(name) do
    # Matches: "Genus species", "Genus x species", "Genus species (variant)", etc.
    # At minimum: one capitalized word, space, one lowercase word
    Regex.match?(~r/^[A-Z][a-z-]+ (x )?[a-z-]+/, name)
  end

  defp save_host(socket, :new, params) do
    case Hosts.create_host(params) do
      {:ok, host} ->
        {:noreply,
         socket
         |> put_flash(:info, "Host created. Now add range and aliases.")
         |> push_navigate(to: ~p"/admin/hosts/#{host.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_host(socket, :edit, params) do
    case Hosts.update_host(socket.assigns.host, params) do
      {:ok, _host} ->
        {:noreply,
         socket
         |> put_flash(:info, "Host updated successfully")
         |> push_navigate(to: ~p"/admin/hosts")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp alias_type_options do
    [
      {"Common Name", "common name"},
      {"Scientific Synonym", "scientific synonym"},
      {"Other", "other"}
    ]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} page_title={@page_title}>
      <div class="max-w-7xl mx-auto">
        <div class="mb-4">
          <.link navigate={~p"/admin/hosts"} class="text-gf-maroon hover:underline text-sm">
            &larr; Back to Hosts
          </.link>
        </div>

        <div class="bg-white border border-gray-200 rounded shadow-sm">
          <div class="px-4 py-3 border-b border-gray-200 bg-gray-50">
            <h4 class="text-lg font-semibold text-gf-maroon">Add/Edit Hosts</h4>
          </div>

          <div class="p-4">
            <%!-- Intro text with links --%>
            <p class="text-sm text-gray-600 mb-4">
              This is for all of the details about a Host. To add a description (which must be referenced to a source) go add <.link
                navigate={~p"/admin/sources"}
                class="text-gf-maroon hover:underline"
              >Sources</.link>, if they do not already exist, then go <span class="text-gray-400">map species to sources with description</span>.
              If you want to assign a
              <.link
                navigate={~p"/admin/taxonomy"}
                class="text-gf-maroon hover:underline"
              >
                Family
              </.link>
              or Section then you will need to have created them first if they do not exist.
            </p>

            <.form for={@form} id="host-form" phx-change="validate" phx-submit="save">
              <%!-- Row: Name --%>
              <div class="mb-3">
                <label class="block text-sm font-medium text-gray-700 mb-1">Name (binomial):</label>
                <%= if @mode == :edit do %>
                  <div class="flex gap-2">
                    <input
                      type="text"
                      value={@host.name}
                      disabled
                      class="flex-1 px-3 py-2 bg-gray-100 border border-gray-300 rounded text-gray-700 text-sm italic"
                    />
                    <button
                      type="button"
                      phx-click="open_rename_modal"
                      class="px-3 py-2 text-sm bg-gray-200 hover:bg-gray-300 border border-gray-300 rounded"
                    >
                      Rename
                    </button>
                  </div>
                <% else %>
                  <.input
                    field={@form[:name]}
                    type="text"
                    placeholder="Enter host name (e.g., Quercus alba)..."
                    class="w-full"
                    required
                  />
                <% end %>
              </div>

              <%!-- Row: Genus | Family --%>
              <div class="grid grid-cols-2 gap-4 mb-3">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">
                    Genus (filled automatically):
                  </label>
                  <input
                    type="text"
                    value={if @taxonomy, do: @taxonomy.genus, else: ""}
                    disabled
                    class="w-full px-3 py-2 bg-gray-100 border border-gray-300 rounded text-gray-500 text-sm italic"
                  />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">
                    Family:
                  </label>
                  <input
                    type="text"
                    value={if @taxonomy, do: @taxonomy.family, else: ""}
                    disabled
                    class="w-full px-3 py-2 bg-gray-100 border border-gray-300 rounded text-gray-500 text-sm"
                  />
                </div>
              </div>

              <%!-- Row: Section | Abundance --%>
              <div class="grid grid-cols-2 gap-4 mb-3">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Section:</label>
                  <input
                    type="text"
                    value={if @taxonomy && @taxonomy.section, do: @taxonomy.section, else: ""}
                    disabled
                    class="w-full px-3 py-2 bg-gray-100 border border-gray-300 rounded text-gray-500 text-sm"
                  />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Abundance:</label>
                  <.input
                    field={@form[:abundance_id]}
                    type="select"
                    options={Enum.map(@abundances, &{&1.abundance, &1.id})}
                    prompt=""
                    class="w-full text-sm"
                  />
                </div>
              </div>

              <%!-- Range Map Section --%>
              <div class="mb-3 border border-gray-300 rounded">
                <div class="grid grid-cols-6 gap-2 p-3">
                  <%!-- Legend --%>
                  <div class="col-span-1">
                    <div class="text-sm font-medium text-gray-700 mb-2">Legend:</div>
                    <div class="space-y-1">
                      <div class="flex items-center gap-2">
                        <div class="w-4 h-4 rounded" style="background-color: ForestGreen;"></div>
                        <span class="text-xs text-gray-600">In Range</span>
                      </div>
                      <div class="flex items-center gap-2">
                        <div
                          class="w-4 h-4 rounded border border-gray-300"
                          style="background-color: White;"
                        >
                        </div>
                        <span class="text-xs text-gray-600">Out of Range</span>
                      </div>
                    </div>
                    <div class="text-sm font-medium text-gray-700 mt-4 mb-2">Map Actions:</div>
                    <div class="space-y-2">
                      <button
                        type="button"
                        phx-click="select_all_places"
                        class="block w-full px-2 py-1 text-xs bg-gray-100 hover:bg-gray-200 border border-gray-300 rounded"
                        disabled={@mode == :new}
                      >
                        Select All
                      </button>
                      <button
                        type="button"
                        phx-click="deselect_all_places"
                        class="block w-full px-2 py-1 text-xs bg-gray-100 hover:bg-gray-200 border border-gray-300 rounded"
                        disabled={@mode == :new}
                      >
                        De-select All
                      </button>
                    </div>
                  </div>
                  <%!-- Map --%>
                  <div class="col-span-5">
                    <label class="block text-sm font-medium text-gray-700 mb-1">Range:</label>
                    <%= if @mode == :edit do %>
                      <div
                        id="host-range-map"
                        phx-hook="RangeMap"
                        phx-update="ignore"
                        data-in-range={Jason.encode!(@places)}
                        data-excluded-range={Jason.encode!([])}
                        data-editable="true"
                        class="border border-gray-300 rounded bg-gray-50 min-h-[300px]"
                      >
                        <div class="flex items-center justify-center h-64 text-gray-400">
                          Loading map...
                        </div>
                      </div>
                    <% else %>
                      <div class="border border-gray-300 rounded bg-gray-100 min-h-[200px] flex items-center justify-center">
                        <p class="text-gray-500 text-sm">Save host first to edit range</p>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>

              <%!-- Aliases Table --%>
              <%= if @mode == :edit do %>
                <div class="mb-3">
                  <label class="block text-sm font-medium text-gray-700 mb-1">Aliases:</label>
                  <div class="border border-gray-300 rounded">
                    <table class="w-full text-sm">
                      <thead class="bg-gray-50">
                        <tr>
                          <th class="px-3 py-1.5 text-left font-medium text-gray-700">Name</th>
                          <th class="px-3 py-1.5 text-left font-medium text-gray-700">Type</th>
                          <th class="px-3 py-1.5 w-10"></th>
                        </tr>
                      </thead>
                      <tbody class="divide-y divide-gray-200">
                        <tr :for={a <- @aliases} class="hover:bg-gray-50">
                          <td class="px-3 py-1.5 italic">{a.name}</td>
                          <td class="px-3 py-1.5">{a.type}</td>
                          <td class="px-3 py-1.5">
                            <button
                              type="button"
                              phx-click="remove_alias"
                              phx-value-alias-id={a.id}
                              class="text-red-600 hover:text-red-800"
                            >
                              <.icon name="ph-x" class="h-4 w-4" />
                            </button>
                          </td>
                        </tr>
                        <tr>
                          <td class="px-3 py-1.5">
                            <input
                              type="text"
                              value={@new_alias_name}
                              placeholder="New alias..."
                              phx-keyup="update_new_alias"
                              phx-value-type={@new_alias_type}
                              class="w-full px-2 py-1 border border-gray-300 rounded text-sm"
                            />
                          </td>
                          <td class="px-3 py-1.5">
                            <select
                              phx-change="update_new_alias"
                              phx-value-name={@new_alias_name}
                              class="w-full px-2 py-1 border border-gray-300 rounded text-sm"
                            >
                              <%= for {label, value} <- alias_type_options() do %>
                                <option value={value} selected={@new_alias_type == value}>
                                  {label}
                                </option>
                              <% end %>
                            </select>
                          </td>
                          <td class="px-3 py-1.5">
                            <button
                              type="button"
                              phx-click="add_alias"
                              class="text-green-600 hover:text-green-800"
                            >
                              <.icon name="ph-plus" class="h-4 w-4" />
                            </button>
                          </td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                </div>
              <% end %>

              <%!-- Data Complete checkbox --%>
              <div class="space-y-2 mb-4">
                <label class="flex items-start gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    name="species[datacomplete]"
                    checked={@form[:datacomplete].value}
                    class="mt-0.5 rounded border-gray-300 text-gf-maroon focus:ring-gf-maroon"
                  />
                  <span class="text-sm text-gray-700">
                    All galls known to occur on this plant have been added to the database, and can be filtered by Location and Detachable. However, sources and images for galls associated with this host may be incomplete or absent, and other filters may not have been entered comprehensively or at all.
                  </span>
                </label>
              </div>

              <%!-- Action buttons --%>
              <div class="flex justify-between items-center pt-3 border-t border-gray-200">
                <div>
                  <%= if @mode == :edit do %>
                    <.link
                      navigate={~p"/host/#{@host.id}"}
                      class="text-sm text-gf-maroon hover:underline"
                    >
                      View public page
                    </.link>
                  <% end %>
                </div>
                <div class="flex gap-2">
                  <.link
                    navigate={~p"/admin/hosts"}
                    class="px-4 py-2 text-sm text-gray-600 hover:text-gray-800"
                  >
                    Cancel
                  </.link>
                  <button
                    type="submit"
                    class="px-4 py-2 bg-gf-maroon text-white text-sm rounded hover:bg-gf-maroon/90"
                  >
                    {if @mode == :new, do: "Create", else: "Save"}
                  </button>
                </div>
              </div>
            </.form>
          </div>
        </div>
      </div>

      <%!-- Rename Modal --%>
      <%= if @show_rename_modal do %>
        <div
          class="fixed inset-0 z-50 overflow-y-auto"
          phx-window-keydown="close_rename_modal"
          phx-key="Escape"
        >
          <div class="flex min-h-full items-center justify-center p-4">
            <%!-- Backdrop --%>
            <div
              class="fixed inset-0 bg-black/50 transition-opacity"
              phx-click="close_rename_modal"
            >
            </div>

            <%!-- Modal --%>
            <div class="relative bg-white rounded-lg shadow-xl w-full max-w-2xl">
              <div class="px-6 py-4 border-b border-gray-200 flex items-center justify-between">
                <h3 class="text-xl font-semibold text-gray-900">Edit Host Name</h3>
                <button
                  type="button"
                  phx-click="close_rename_modal"
                  class="text-gray-400 hover:text-gray-600"
                >
                  <.icon name="ph-x" class="h-6 w-6" />
                </button>
              </div>

              <div class="p-6">
                <input
                  type="text"
                  value={@rename_value}
                  phx-keyup="update_rename_value"
                  phx-key="Enter"
                  class="w-full px-4 py-3 border border-gray-300 rounded text-lg focus:ring-gf-maroon focus:border-gf-maroon"
                  autofocus
                />

                <div class="mt-5">
                  <label class="flex items-center gap-3 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={@add_alias_on_rename}
                      phx-click="toggle_add_alias_on_rename"
                      class="w-5 h-5 rounded border-gray-300 text-gf-maroon focus:ring-gf-maroon"
                    />
                    <span class="text-base text-gray-700">Add Alias for old name?</span>
                  </label>
                </div>

                <div class="mt-4 text-sm text-gray-500">
                  If you want to reassign the species to a different genus, enter the new name
                  with the new genus. If the genus doesn't exist, it will be created under the same family.
                  If it exists, the species will be reassigned to that genus.
                </div>
              </div>

              <div class="px-6 py-4 border-t border-gray-200 flex justify-end gap-3">
                <button
                  type="button"
                  phx-click="close_rename_modal"
                  class="px-5 py-2.5 text-base text-gray-600 hover:text-gray-800"
                >
                  Cancel
                </button>
                <button
                  type="button"
                  phx-click="do_rename"
                  class="px-5 py-2.5 bg-gf-maroon text-white text-base rounded hover:bg-gf-maroon/90"
                >
                  Save Changes
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </Layouts.admin>
    """
  end
end
