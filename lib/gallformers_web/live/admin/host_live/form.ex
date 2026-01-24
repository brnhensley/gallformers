defmodule GallformersWeb.Admin.HostLive.Form do
  @moduledoc """
  Admin form for creating and editing host species.
  Layout mirrors V1 host admin for consistency.
  """
  use GallformersWeb, :live_view
  use GallformersWeb.Admin.FormHelpers

  alias Gallformers.Hosts
  alias Gallformers.Places
  alias Gallformers.Repo
  alias Gallformers.Species
  alias Gallformers.Species.Species, as: SpeciesSchema
  alias Gallformers.Taxonomy
  alias GallformersWeb.Admin.DeferredChanges

  import GallformersWeb.Admin.FormComponents, only: [alias_editor: 1, form_actions: 1]

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
      |> init_form_state()

    {:ok, socket}
  end

  def close_form(socket) do
    push_navigate(socket, to: ~p"/admin/hosts")
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
    # Deferred changes tracking
    |> assign(DeferredChanges.init(:aliases, []))
    |> assign(:original_places, [])
    |> assign(:places, [])
    |> assign(:taxonomy, nil)
    |> assign(:new_alias_name, "")
    |> assign(:new_alias_type, "common")
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
          # Deferred changes tracking
          |> assign(DeferredChanges.init(:aliases, aliases))
          |> assign(:original_places, places)
          |> assign(:places, places)
          |> assign(:taxonomy, taxonomy)
          |> assign(:new_alias_name, "")
          |> assign(:new_alias_type, "common")
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

    {:noreply, socket |> assign(:form, to_form(changeset)) |> mark_dirty()}
  end

  # Catch-all for validate events that don't match the expected form structure
  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save", %{"species" => params}, socket) do
    params = Map.put(params, "taxoncode", "plant")
    save_host(socket, socket.assigns.mode, params)
  end

  @impl true
  def handle_event(event, params, socket)
      when event in ~w(request_cancel cancel_discard confirm_discard) do
    handle_form_event(event, params, socket)
  end

  # Alias events

  @impl true
  def handle_event("update_new_alias", %{"value" => name, "type" => type}, socket) do
    # Name field changed (from phx-keyup on text input)
    {:noreply, assign(socket, new_alias_name: name, new_alias_type: type)}
  end

  @impl true
  def handle_event("update_new_alias", %{"value" => type, "name" => name}, socket) do
    # Type field changed (from phx-change on select)
    {:noreply, assign(socket, new_alias_name: name, new_alias_type: type)}
  end

  @impl true
  def handle_event("add_alias", _params, socket) do
    name = String.trim(socket.assigns.new_alias_name)
    type = socket.assigns.new_alias_type

    cond do
      name == "" ->
        {:noreply, put_flash(socket, :error, "Alias name cannot be empty")}

      DeferredChanges.exists?(socket, :aliases, :name, name) ->
        {:noreply, put_flash(socket, :error, "Alias already exists")}

      true ->
        socket =
          socket
          |> DeferredChanges.add_pending(:aliases, %{name: name, type: type})
          |> assign(:new_alias_name, "")
          |> mark_dirty()

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_alias", %{"alias-id" => alias_id}, socket) do
    alias_id = String.to_integer(alias_id)

    socket =
      socket
      |> DeferredChanges.remove_pending(:aliases, alias_id)
      |> mark_dirty()

    {:noreply, socket}
  end

  # Range/Place events

  @impl true
  def handle_event("toggle_region", %{"code" => code}, socket) do
    {:noreply, toggle_region(socket, code)}
  end

  @impl true
  def handle_event("select_all_places", _params, socket) do
    if socket.assigns.mode == :edit do
      # Select all in local state - don't save to DB yet
      all_codes = Enum.map(socket.assigns.all_places, & &1.code)
      {:noreply, socket |> assign(:places, all_codes) |> mark_dirty()}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("deselect_all_places", _params, socket) do
    if socket.assigns.mode == :edit do
      # Deselect all in local state - don't save to DB yet
      {:noreply, socket |> assign(:places, []) |> mark_dirty()}
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
  def handle_event("delete", _params, socket) do
    case Hosts.delete_host(socket.assigns.host.id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Host deleted successfully")
         |> push_navigate(to: ~p"/admin/hosts")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete host")}
    end
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

  # Helper functions for handle_event

  defp toggle_region(%{assigns: %{mode: mode}} = socket, _code) when mode != :edit, do: socket

  defp toggle_region(socket, code) do
    place = Enum.find(socket.assigns.all_places, &(&1.code == code))

    if place do
      new_places = toggle_place_code(socket.assigns.places, code)
      socket |> assign(:places, new_places) |> mark_dirty()
    else
      socket
    end
  end

  defp toggle_place_code(places, code) do
    if code in places, do: Enum.reject(places, &(&1 == code)), else: places ++ [code]
  end

  defp save_host(socket, :new, params) do
    case Hosts.create_host(params) do
      {:ok, host} ->
        # Redirect to edit mode for the new host so user can add range/aliases
        {:noreply,
         socket
         |> put_flash(:info, "Host created. Now add range and aliases.")
         |> push_navigate(to: ~p"/admin/hosts/#{host.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_host(socket, :edit, params) do
    host_id = socket.assigns.host.id

    # Compute changes using DeferredChanges
    {aliases_to_add, aliases_to_remove} = DeferredChanges.compute_changes(socket, :aliases)

    # Wrap all saves in a transaction for atomicity
    transaction_result =
      Repo.transaction(fn ->
        case Hosts.update_host(socket.assigns.host, params) do
          {:ok, updated_host} ->
            # Save aliases
            save_alias_changes(host_id, aliases_to_add, aliases_to_remove)

            # Save places - diff original vs current
            save_place_changes(
              host_id,
              socket.assigns.original_places,
              socket.assigns.places,
              socket.assigns.all_places
            )

            updated_host

          {:error, changeset} ->
            Repo.rollback(changeset)
        end
      end)

    case transaction_result do
      {:ok, updated_host} ->
        # Reload data from DB to get actual IDs for new records
        aliases = Hosts.get_aliases_for_host_full(host_id)
        places = Hosts.get_places_for_host(host_id)

        # Stay on page, update state to reflect saved data
        {:noreply,
         socket
         |> assign(:host, updated_host)
         |> DeferredChanges.refresh(:aliases, aliases)
         |> assign(:original_places, places)
         |> assign(:places, places)
         |> reset_dirty()
         |> put_flash(:info, "Host saved successfully")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to save host. Please try again.")}
    end
  end

  # Helper to save alias changes
  defp save_alias_changes(host_id, to_add, to_remove) do
    # Delete removed aliases
    for alias_id <- to_remove do
      Hosts.remove_alias_from_host(host_id, alias_id)
    end

    # Add new aliases
    for alias <- to_add do
      Hosts.create_alias_for_host(host_id, %{name: alias.name, type: alias.type})
    end
  end

  # Helper to save place changes
  defp save_place_changes(host_id, original_places, current_places, all_places) do
    # Convert to place_ids
    place_code_to_id = Map.new(all_places, &{&1.code, &1.id})

    original_set = MapSet.new(original_places)
    current_set = MapSet.new(current_places)

    # Only update if there are changes
    if original_set != current_set do
      place_ids =
        Enum.map(current_places, &Map.get(place_code_to_id, &1)) |> Enum.reject(&is_nil/1)

      Hosts.update_host_places(host_id, place_ids)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin
      flash={@flash}
      current_user={@current_user}
      page_title={@page_title}
      public_url={if @mode == :edit, do: ~p"/host/#{@host.id}"}
    >
      <Layouts.admin_edit_layout
        back_path={~p"/admin/hosts"}
        back_label="Back to Hosts"
        title={if @mode == :new, do: "Add New Host", else: "Edit Host"}
      >
        <:intro>
          This is for all of the details about a Host. To add a description (which must be referenced to a source) go add <.link
            navigate={~p"/admin/sources"}
            class="hover:underline"
          >Sources</.link>,
          if they do not already exist, then map species to sources with description.
          If you want to assign a
          <.link navigate={~p"/admin/taxonomy"} class="hover:underline">Family</.link>
          or Section then you will need to have created them first if they do not exist.
        </:intro>

        <:quick_links :if={@mode == :edit}>
          <.link
            navigate={~p"/admin/images?species_id=#{@host.id}"}
            class="text-sm hover:underline mr-4"
          >
            Manage Images
          </.link>
          <.link
            navigate={~p"/admin/species-sources/find?species_id=#{@host.id}"}
            class="text-sm hover:underline"
          >
            Species-Source Mappings
          </.link>
        </:quick_links>

        <.form for={@form} id="host-form" phx-change="validate" phx-submit="save">
          <%!-- Row: Name --%>
          <div class="mb-3">
            <label class="gf-label">Name (binomial):</label>
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
              <label class="gf-label">
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
              <label class="gf-label">
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
              <label class="gf-label">Section:</label>
              <input
                type="text"
                value={if @taxonomy && @taxonomy.section, do: @taxonomy.section, else: ""}
                disabled
                class="w-full px-3 py-2 bg-gray-100 border border-gray-300 rounded text-gray-500 text-sm"
              />
            </div>
            <div>
              <label class="gf-label">Abundance:</label>
              <.input
                field={@form[:abundance_id]}
                type="select"
                options={Enum.map(@abundances, &{&1.abundance, &1.id})}
                prompt=""
                class="gf-select w-full text-sm"
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
                    <div class="w-4 h-4 rounded bg-green-700"></div>
                    <span class="text-xs text-gray-600">In Range</span>
                  </div>
                  <div class="flex items-center gap-2">
                    <div class="w-4 h-4 rounded border border-gray-300 bg-white"></div>
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
                <label class="gf-label">Range:</label>
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
            <.alias_editor
              aliases={@aliases}
              new_alias_name={@new_alias_name}
              new_alias_type={@new_alias_type}
            />
          <% end %>

          <%!-- Data Complete checkbox --%>
          <div class="space-y-2 mb-4">
            <.input
              type="checkbox"
              field={@form[:datacomplete]}
              label="All galls known to occur on this plant have been added to the database, and can be filtered by Location and Detachable. However, sources and images for galls associated with this host may be incomplete or absent, and other filters may not have been entered comprehensively or at all."
            />
          </div>

          <%!-- Action buttons --%>
          <div class="flex justify-between pt-3 border-t border-gray-200">
            <div>
              <button
                :if={@mode == :edit}
                type="button"
                phx-click="delete"
                data-confirm="Are you sure you want to delete this host? This will remove all associated gall mappings and range data."
                class="gf-btn gf-btn-danger"
              >
                Delete
              </button>
            </div>
            <.form_actions form_dirty={@form_dirty} mode={@mode} />
          </div>
        </.form>

        <.discard_confirm_modal show={@show_discard_confirm} />
      </Layouts.admin_edit_layout>

      <.rename_modal
        show={@show_rename_modal}
        value={@rename_value}
        add_alias_checked={@add_alias_on_rename}
        entity_type="Host"
      />
    </Layouts.admin>
    """
  end
end
