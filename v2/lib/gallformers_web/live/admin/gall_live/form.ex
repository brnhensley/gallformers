defmodule GallformersWeb.Admin.GallLive.Form do
  @moduledoc """
  Admin form for creating and editing galls.
  Layout mirrors V1 gall admin for consistency.
  """
  use GallformersWeb, :live_view
  use GallformersWeb.Admin.FormHelpers

  alias Gallformers.Species
  alias Gallformers.Species.Species, as: SpeciesSchema

  @detachable_options [
    {"", 0},
    {"integral", 1},
    {"detachable", 2},
    {"both", 3}
  ]

  @impl true
  def mount(_params, session, socket) do
    current_user = session["current_user"]
    filter_options = Species.get_all_filter_options()

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:page_title, "Gall")
      |> assign(:abundances, Species.list_abundances())
      |> assign(:filter_options, filter_options)
      |> assign(:detachable_options, @detachable_options)
      |> init_form_state()

    {:ok, socket}
  end

  def close_form(socket) do
    push_navigate(socket, to: ~p"/admin/galls")
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    gall = %SpeciesSchema{taxoncode: "gall"}
    changeset = Species.change_species(gall)

    socket
    |> assign(:page_title, "New Gall")
    |> assign(:gall, gall)
    |> assign(:gall_data, nil)
    |> assign(:form, to_form(changeset))
    |> assign(:mode, :new)
    # Original data from DB (for comparison)
    |> assign(:original_aliases, [])
    |> assign(:original_hosts, [])
    |> assign(:original_filter_values, empty_filter_values())
    |> assign(:original_detachable, 0)
    |> assign(:original_undescribed, false)
    # Pending state (what user sees and edits)
    |> assign(:aliases, [])
    |> assign(:hosts, [])
    |> assign(:taxonomy, nil)
    |> assign(:filter_values, empty_filter_values())
    |> assign(:gall_id, nil)
    |> assign(:detachable, 0)
    |> assign(:undescribed, false)
    |> assign(:new_alias_name, "")
    |> assign(:new_alias_type, "common name")
    |> assign(:host_search_query, "")
    |> assign(:host_search_results, [])
    |> assign(:host_dropdown_open, false)
    |> assign(:filter_search, init_filter_search_state())
    |> assign(:filter_dropdown_open, nil)
    # Rename modal state
    |> assign(:show_rename_modal, false)
    |> assign(:rename_value, "")
    |> assign(:add_alias_on_rename, false)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    species_id = String.to_integer(id)

    case Species.get_gall_for_admin_edit(species_id) do
      nil ->
        socket
        |> put_flash(:error, "Gall not found")
        |> push_navigate(to: ~p"/admin/galls")

      gall_data ->
        species = Species.get_species!(species_id)

        if species.taxoncode != "gall" do
          socket
          |> put_flash(:error, "This is not a gall. Use the Host admin for host species.")
          |> push_navigate(to: ~p"/admin/galls")
        else
          changeset = Species.change_species(species)
          aliases = Species.get_aliases_for_species(species_id)
          hosts = Gallformers.Hosts.get_hosts_for_gall(species_id)
          taxonomy = Gallformers.Taxonomy.get_taxonomy_for_species(species_id)
          filter_values = gall_data.filter_values
          detachable = gall_data.detachable || 0
          undescribed = gall_data.undescribed || false

          socket
          |> assign(:page_title, "Edit Gall - #{species.name}")
          |> assign(:gall, species)
          |> assign(:gall_data, gall_data)
          |> assign(:form, to_form(changeset))
          |> assign(:mode, :edit)
          # Original data from DB (for comparison on save)
          |> assign(:original_aliases, aliases)
          |> assign(:original_hosts, hosts)
          |> assign(:original_filter_values, filter_values)
          |> assign(:original_detachable, detachable)
          |> assign(:original_undescribed, undescribed)
          # Pending state (what user sees and edits)
          |> assign(:aliases, aliases)
          |> assign(:hosts, hosts)
          |> assign(:taxonomy, taxonomy)
          |> assign(:filter_values, filter_values)
          |> assign(:gall_id, gall_data.gall_id)
          |> assign(:detachable, detachable)
          |> assign(:undescribed, undescribed)
          |> assign(:new_alias_name, "")
          |> assign(:new_alias_type, "common name")
          |> assign(:host_search_query, "")
          |> assign(:host_search_results, [])
          |> assign(:host_dropdown_open, false)
          |> assign(:filter_search, init_filter_search_state())
          |> assign(:filter_dropdown_open, nil)
          # Rename modal state
          |> assign(:show_rename_modal, false)
          |> assign(:rename_value, species.name)
          |> assign(:add_alias_on_rename, false)
        end
    end
  end

  defp empty_filter_values do
    %{
      colors: [],
      shapes: [],
      textures: [],
      alignments: [],
      walls: [],
      cells: [],
      locations: [],
      forms: [],
      seasons: []
    }
  end

  defp init_filter_search_state do
    %{
      colors: "",
      shapes: "",
      textures: "",
      alignments: "",
      walls: "",
      cells: "",
      locations: "",
      forms: "",
      seasons: ""
    }
  end

  # Event handlers

  @impl true
  def handle_event("validate", %{"species" => params}, socket) do
    changeset =
      socket.assigns.gall
      |> Species.change_species(params)
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(:form, to_form(changeset)) |> mark_dirty()}
  end

  @impl true
  def handle_event("save", %{"species" => params}, socket) do
    params = Map.put(params, "taxoncode", "gall")
    save_gall(socket, socket.assigns.mode, params)
  end

  @impl true
  def handle_event(event, params, socket)
      when event in ~w(request_cancel cancel_discard confirm_discard) do
    handle_form_event(event, params, socket)
  end

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

    if name == "" do
      {:noreply, put_flash(socket, :error, "Alias name cannot be empty")}
    else
      # Check for duplicate
      if Enum.any?(socket.assigns.aliases, &(&1.name == name)) do
        {:noreply, put_flash(socket, :error, "Alias already exists")}
      else
        # Add to pending aliases (use negative temp ID for new aliases)
        temp_id = -System.unique_integer([:positive])
        new_alias = %{id: temp_id, name: name, type: type, pending: true}
        aliases = socket.assigns.aliases ++ [new_alias]

        {:noreply,
         socket
         |> assign(:aliases, aliases)
         |> assign(:new_alias_name, "")
         |> mark_dirty()}
      end
    end
  end

  @impl true
  def handle_event("remove_alias", %{"alias-id" => alias_id}, socket) do
    alias_id = String.to_integer(alias_id)
    aliases = Enum.reject(socket.assigns.aliases, &(&1.id == alias_id))

    {:noreply,
     socket
     |> assign(:aliases, aliases)
     |> mark_dirty()}
  end

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
  def handle_event("add_host", %{"id" => host_id}, socket) do
    host_id = String.to_integer(host_id)

    # Check if already added
    if Enum.any?(socket.assigns.hosts, &(&1.host_species_id == host_id)) do
      {:noreply, put_flash(socket, :error, "Host already associated")}
    else
      # Find the host in search results to get its name
      host_result = Enum.find(socket.assigns.host_search_results, &(&1.id == host_id))

      if host_result do
        # Add to pending hosts with temp relation ID
        temp_relation_id = -System.unique_integer([:positive])

        new_host = %{
          host_species_id: host_id,
          host_name: host_result.name,
          host_relation_id: temp_relation_id,
          pending: true
        }

        hosts = socket.assigns.hosts ++ [new_host]

        {:noreply,
         socket
         |> assign(:hosts, hosts)
         |> assign(:host_search_query, "")
         |> assign(:host_search_results, [])
         |> assign(:host_dropdown_open, false)
         |> mark_dirty()}
      else
        {:noreply, put_flash(socket, :error, "Host not found")}
      end
    end
  end

  @impl true
  def handle_event("remove_host", params, socket) do
    # Support both new format ("id") and legacy format ("relation-id")
    relation_id = String.to_integer(params["id"] || params["relation-id"])
    hosts = Enum.reject(socket.assigns.hosts, &(&1.host_relation_id == relation_id))

    {:noreply,
     socket
     |> assign(:hosts, hosts)
     |> mark_dirty()}
  end

  @impl true
  def handle_event("update_detachable", %{"value" => value}, socket) do
    detachable = String.to_integer(value)
    # Just update local state, don't save to DB yet
    {:noreply, socket |> assign(:detachable, detachable) |> mark_dirty()}
  end

  @impl true
  def handle_event("toggle_undescribed", _params, socket) do
    new_value = !socket.assigns.undescribed
    # Just update local state, don't save to DB yet
    {:noreply, socket |> assign(:undescribed, new_value) |> mark_dirty()}
  end

  @impl true
  def handle_event("filter_search", %{"type" => type, "value" => query}, socket) do
    filter_type = String.to_atom(type)
    filter_search = Map.put(socket.assigns.filter_search, filter_type, query)
    # Open dropdown when typing
    {:noreply,
     socket |> assign(:filter_search, filter_search) |> assign(:filter_dropdown_open, filter_type)}
  end

  @impl true
  def handle_event("open_filter_dropdown", %{"type" => type}, socket) do
    filter_type = String.to_atom(type)
    {:noreply, assign(socket, :filter_dropdown_open, filter_type)}
  end

  @impl true
  def handle_event("close_filter_dropdown", _params, socket) do
    {:noreply, assign(socket, :filter_dropdown_open, nil)}
  end

  @impl true
  def handle_event("add_filter", %{"type" => type, "id" => id}, socket) do
    filter_type = String.to_atom(type)
    filter_id = String.to_integer(id)

    # Find the option from filter_options
    options = Map.get(socket.assigns.filter_options, filter_type, [])
    option = Enum.find(options, &(&1.id == filter_id))

    if option do
      current_values = Map.get(socket.assigns.filter_values, filter_type, [])

      # Check for duplicate
      if Enum.any?(current_values, &(&1.id == filter_id)) do
        {:noreply, put_flash(socket, :error, "Already selected")}
      else
        new_values = current_values ++ [option]
        filter_values = Map.put(socket.assigns.filter_values, filter_type, new_values)
        filter_search = Map.put(socket.assigns.filter_search, filter_type, "")

        {:noreply,
         socket
         |> assign(:filter_values, filter_values)
         |> assign(:filter_search, filter_search)
         |> assign(:filter_dropdown_open, nil)
         |> mark_dirty()}
      end
    else
      {:noreply, put_flash(socket, :error, "Option not found")}
    end
  end

  @impl true
  def handle_event("remove_filter", %{"type" => type, "id" => id}, socket) do
    filter_type = String.to_atom(type)
    filter_id = String.to_integer(id)

    current_values = Map.get(socket.assigns.filter_values, filter_type, [])
    new_values = Enum.reject(current_values, &(&1.id == filter_id))
    filter_values = Map.put(socket.assigns.filter_values, filter_type, new_values)

    {:noreply, socket |> assign(:filter_values, filter_values) |> mark_dirty()}
  end

  # Rename modal events

  @impl true
  def handle_event("open_rename_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_rename_modal, true)
     |> assign(:rename_value, socket.assigns.gall.name)
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
    old_name = socket.assigns.gall.name

    cond do
      new_name == "" ->
        {:noreply, put_flash(socket, :error, "Name cannot be empty")}

      new_name == old_name ->
        {:noreply, assign(socket, :show_rename_modal, false)}

      not valid_species_name?(new_name) ->
        {:noreply, put_flash(socket, :error, "Name must be a valid species name (Genus species)")}

      true ->
        case Species.rename_species(
               socket.assigns.gall.id,
               new_name,
               socket.assigns.add_alias_on_rename
             ) do
          {:ok, updated_species} ->
            # Reload aliases if we added one
            aliases =
              if socket.assigns.add_alias_on_rename do
                Species.get_aliases_for_species(socket.assigns.gall.id)
              else
                socket.assigns.aliases
              end

            {:noreply,
             socket
             |> assign(:gall, updated_species)
             |> assign(:aliases, aliases)
             |> assign(:show_rename_modal, false)
             |> assign(:page_title, "Edit Gall - #{new_name}")
             |> put_flash(:info, "Gall renamed successfully")}

          {:error, :name_exists} ->
            {:noreply, put_flash(socket, :error, "That name is already in use")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to rename gall")}
        end
    end
  end

  # Basic validation for species name (Genus species format)
  defp valid_species_name?(name) do
    # Matches: "Genus species", "Genus x species", "Genus species (variant)", etc.
    # At minimum: one capitalized word, space, one lowercase word
    Regex.match?(~r/^[A-Z][a-z-]+ (x )?[a-z-]+/, name)
  end

  defp save_gall(socket, :new, params) do
    case Species.create_species(params) do
      {:ok, gall} ->
        # Redirect to edit mode for the new gall so user can add hosts/filters
        {:noreply,
         socket
         |> put_flash(:info, "Gall created. Now add hosts and filter properties.")
         |> push_navigate(to: ~p"/admin/galls/#{gall.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_gall(socket, :edit, params) do
    case Species.update_species(socket.assigns.gall, params) do
      {:ok, updated_gall} ->
        # Now persist all pending changes
        gall_id = socket.assigns.gall_id
        species_id = socket.assigns.gall.id

        # Save aliases - diff original vs current
        save_alias_changes(species_id, socket.assigns.original_aliases, socket.assigns.aliases)

        # Save hosts - diff original vs current
        save_host_changes(species_id, socket.assigns.original_hosts, socket.assigns.hosts)

        # Save filter values - diff original vs current
        if gall_id do
          save_filter_changes(
            gall_id,
            socket.assigns.original_filter_values,
            socket.assigns.filter_values
          )

          # Save gall properties (detachable, undescribed)
          Species.update_gall_properties(gall_id, %{
            detachable: socket.assigns.detachable,
            undescribed: socket.assigns.undescribed
          })
        end

        # Reload data from DB to get actual IDs for new records
        aliases = Species.get_aliases_for_species(species_id)
        hosts = Gallformers.Hosts.get_hosts_for_gall(species_id)

        filter_values =
          if gall_id, do: Species.get_gall_filter_values(gall_id), else: empty_filter_values()

        # Stay on page, update state to reflect saved data
        {:noreply,
         socket
         |> assign(:gall, updated_gall)
         |> assign(:original_aliases, aliases)
         |> assign(:original_hosts, hosts)
         |> assign(:original_filter_values, filter_values)
         |> assign(:original_detachable, socket.assigns.detachable)
         |> assign(:original_undescribed, socket.assigns.undescribed)
         |> assign(:aliases, aliases)
         |> assign(:hosts, hosts)
         |> assign(:filter_values, filter_values)
         |> reset_dirty()
         |> put_flash(:info, "Gall saved successfully")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  # Helper to save alias changes
  defp save_alias_changes(species_id, original_aliases, current_aliases) do
    original_ids = MapSet.new(Enum.map(original_aliases, & &1.id))
    current_ids = MapSet.new(Enum.map(current_aliases, & &1.id) |> Enum.filter(&(&1 > 0)))

    # Delete removed aliases
    removed_ids = MapSet.difference(original_ids, current_ids)

    for alias_id <- removed_ids do
      Species.remove_alias_from_species(species_id, alias_id)
    end

    # Add new aliases (those with negative/temp IDs or marked as pending)
    for alias <- current_aliases, Map.get(alias, :pending, false) or alias.id < 0 do
      Species.create_alias_for_species(species_id, %{name: alias.name, type: alias.type})
    end
  end

  # Helper to save host changes
  defp save_host_changes(species_id, original_hosts, current_hosts) do
    original_relation_ids = MapSet.new(Enum.map(original_hosts, & &1.host_relation_id))

    current_relation_ids =
      MapSet.new(
        current_hosts
        |> Enum.map(& &1.host_relation_id)
        |> Enum.filter(&(&1 > 0))
      )

    # Delete removed hosts
    removed_ids = MapSet.difference(original_relation_ids, current_relation_ids)

    for relation_id <- removed_ids do
      Species.remove_host_from_species(relation_id)
    end

    # Add new hosts (those with negative/temp relation IDs or marked as pending)
    for host <- current_hosts, Map.get(host, :pending, false) or host.host_relation_id < 0 do
      Species.add_host_to_species(species_id, host.host_species_id)
    end
  end

  # Helper to save filter changes
  defp save_filter_changes(gall_id, original_values, current_values) do
    filter_types = [
      :colors,
      :shapes,
      :textures,
      :alignments,
      :walls,
      :cells,
      :locations,
      :forms,
      :seasons
    ]

    for filter_type <- filter_types do
      original = Map.get(original_values, filter_type, [])
      current = Map.get(current_values, filter_type, [])

      original_ids = MapSet.new(Enum.map(original, & &1.id))
      current_ids = MapSet.new(Enum.map(current, & &1.id))

      # Remove deleted filters
      removed_ids = MapSet.difference(original_ids, current_ids)

      for filter_id <- removed_ids do
        Species.remove_filter_field_from_gall(gall_id, filter_type, filter_id)
      end

      # Add new filters
      added_ids = MapSet.difference(current_ids, original_ids)

      for filter_id <- added_ids do
        Species.add_filter_field_to_gall(gall_id, filter_type, filter_id)
      end
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
      <Layouts.admin_edit_layout
        back_path={~p"/admin/galls"}
        back_label="Back to Galls"
        title={if @mode == :new, do: "Add New Gall", else: "Edit Gall"}
      >
        <:intro>
          This is for all of the details about a Gall. To add a description (which must be referenced to a source) go add <.link
            navigate={~p"/admin/sources"}
            class="text-gf-maroon hover:underline"
          >Sources</.link>,
          if they do not already exist, then map species to sources with description.
          To associate a gall with all plants in a genus, add one species here first, then go to Gall-Host Mappings.
        </:intro>

        <:quick_links :if={@mode == :edit}>
          <.link
            navigate={~p"/admin/images?species_id=#{@gall.id}"}
            class="text-sm text-gf-maroon hover:underline mr-4"
          >
            Manage Images
          </.link>
          <.link
            navigate={~p"/admin/gallhost?id=#{@gall.id}"}
            class="text-sm text-gf-maroon hover:underline mr-4"
          >
            Gall-Host Mappings
          </.link>
          <.link
            navigate={~p"/admin/species-sources/find?species_id=#{@gall.id}"}
            class="text-sm text-gf-maroon hover:underline"
          >
            Species-Source Mappings
          </.link>
        </:quick_links>

        <%!-- Add Undescribed button (new mode only) --%>
        <%= if @mode == :new do %>
          <div class="mb-3">
            <button
              type="button"
              disabled
              class="px-3 py-1 text-sm bg-gray-100 text-gray-400 border border-gray-300 rounded cursor-not-allowed"
              title="Coming Soon"
            >
              Add Undescribed (Coming Soon)
            </button>
          </div>
        <% end %>

        <.form for={@form} id="gall-form" phx-change="validate" phx-submit="save">
          <%!-- Row: Name --%>
          <div class="mb-3">
            <label class="block text-sm font-medium text-gray-700 mb-1">Name (binomial):</label>
            <%= if @mode == :edit do %>
              <div class="flex gap-2">
                <input
                  type="text"
                  value={@gall.name}
                  disabled
                  class="flex-1 px-3 py-2 bg-gray-100 border border-gray-300 rounded text-gray-700 text-sm"
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
                placeholder="Enter gall name..."
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
                class="w-full px-3 py-2 bg-gray-100 border border-gray-300 rounded text-gray-500 text-sm"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                Family (required):
              </label>
              <input
                type="text"
                value={if @taxonomy, do: @taxonomy.family, else: ""}
                disabled
                class="w-full px-3 py-2 bg-gray-100 border border-gray-300 rounded text-gray-500 text-sm"
              />
            </div>
          </div>

          <%!-- Row: Hosts --%>
          <div class="mb-3">
            <%= if @mode == :edit do %>
              <.multi_select_dropdown
                id="host-picker"
                label="Hosts (required):"
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
                placeholder="Search hosts..."
                on_search="search_hosts"
                on_add="add_host"
                on_remove="remove_host"
                on_open="open_host_dropdown"
                on_close="close_host_dropdown"
              />
              <%= if @hosts == [] do %>
                <p class="text-red-600 text-xs mt-1">
                  You must map this gall to at least one host.
                </p>
              <% end %>
            <% else %>
              <label class="block text-sm font-medium text-gray-700 mb-1">Hosts (required):</label>
              <input
                type="text"
                disabled
                placeholder="Save gall first to add hosts"
                class="w-full px-3 py-2 bg-gray-100 border border-gray-300 rounded text-gray-400 text-sm"
              />
            <% end %>
          </div>

          <%= if @mode == :edit do %>
            <%!-- Row: Detachable | Walls | Cells | Alignment --%>
            <div class="grid grid-cols-4 gap-3 mb-3">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Detachable:</label>
                <select
                  phx-change="update_detachable"
                  name="value"
                  class="w-full px-2 py-1.5 border border-gray-300 rounded text-sm"
                >
                  <%= for {label, id} <- @detachable_options do %>
                    <option value={id} selected={@detachable == id}>{label}</option>
                  <% end %>
                </select>
              </div>
              <.multi_select_dropdown
                id="walls"
                label="Walls:"
                type={:walls}
                options={@filter_options.walls}
                selected={@filter_values.walls}
                search_query={@filter_search.walls}
                dropdown_open={@filter_dropdown_open == :walls}
                item_label={:field}
                on_search="filter_search"
                on_add="add_filter"
                on_remove="remove_filter"
                on_open="open_filter_dropdown"
                on_close="close_filter_dropdown"
              />
              <.multi_select_dropdown
                id="cells"
                label="Cells:"
                type={:cells}
                options={@filter_options.cells}
                selected={@filter_values.cells}
                search_query={@filter_search.cells}
                dropdown_open={@filter_dropdown_open == :cells}
                item_label={:field}
                on_search="filter_search"
                on_add="add_filter"
                on_remove="remove_filter"
                on_open="open_filter_dropdown"
                on_close="close_filter_dropdown"
              />
              <.multi_select_dropdown
                id="alignments"
                label="Alignment(s):"
                type={:alignments}
                options={@filter_options.alignments}
                selected={@filter_values.alignments}
                search_query={@filter_search.alignments}
                dropdown_open={@filter_dropdown_open == :alignments}
                item_label={:field}
                on_search="filter_search"
                on_add="add_filter"
                on_remove="remove_filter"
                on_open="open_filter_dropdown"
                on_close="close_filter_dropdown"
              />
            </div>

            <%!-- Row: Color | Shape | Season | Form --%>
            <div class="grid grid-cols-4 gap-3 mb-3">
              <.multi_select_dropdown
                id="colors"
                label="Color(s):"
                type={:colors}
                options={@filter_options.colors}
                selected={@filter_values.colors}
                search_query={@filter_search.colors}
                dropdown_open={@filter_dropdown_open == :colors}
                item_label={:field}
                on_search="filter_search"
                on_add="add_filter"
                on_remove="remove_filter"
                on_open="open_filter_dropdown"
                on_close="close_filter_dropdown"
              />
              <.multi_select_dropdown
                id="shapes"
                label="Shape(s):"
                type={:shapes}
                options={@filter_options.shapes}
                selected={@filter_values.shapes}
                search_query={@filter_search.shapes}
                dropdown_open={@filter_dropdown_open == :shapes}
                item_label={:field}
                on_search="filter_search"
                on_add="add_filter"
                on_remove="remove_filter"
                on_open="open_filter_dropdown"
                on_close="close_filter_dropdown"
              />
              <.multi_select_dropdown
                id="seasons"
                label="Season(s):"
                type={:seasons}
                options={@filter_options.seasons}
                selected={@filter_values.seasons}
                search_query={@filter_search.seasons}
                dropdown_open={@filter_dropdown_open == :seasons}
                item_label={:field}
                on_search="filter_search"
                on_add="add_filter"
                on_remove="remove_filter"
                on_open="open_filter_dropdown"
                on_close="close_filter_dropdown"
              />
              <.multi_select_dropdown
                id="forms"
                label="Form(s):"
                type={:forms}
                options={@filter_options.forms}
                selected={@filter_values.forms}
                search_query={@filter_search.forms}
                dropdown_open={@filter_dropdown_open == :forms}
                item_label={:field}
                on_search="filter_search"
                on_add="add_filter"
                on_remove="remove_filter"
                on_open="open_filter_dropdown"
                on_close="close_filter_dropdown"
              />
            </div>

            <%!-- Row: Location | Texture | Abundance --%>
            <div class="grid grid-cols-3 gap-3 mb-3">
              <.multi_select_dropdown
                id="locations"
                label="Location(s):"
                type={:locations}
                options={@filter_options.locations}
                selected={@filter_values.locations}
                search_query={@filter_search.locations}
                dropdown_open={@filter_dropdown_open == :locations}
                item_label={:field}
                on_search="filter_search"
                on_add="add_filter"
                on_remove="remove_filter"
                on_open="open_filter_dropdown"
                on_close="close_filter_dropdown"
              />
              <.multi_select_dropdown
                id="textures"
                label="Texture(s):"
                type={:textures}
                options={@filter_options.textures}
                selected={@filter_values.textures}
                search_query={@filter_search.textures}
                dropdown_open={@filter_dropdown_open == :textures}
                item_label={:field}
                on_search="filter_search"
                on_add="add_filter"
                on_remove="remove_filter"
                on_open="open_filter_dropdown"
                on_close="close_filter_dropdown"
              />
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

            <%!-- Aliases table --%>
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

          <%!-- Checkboxes --%>
          <div class="space-y-2 mb-4">
            <label class="flex items-start gap-2 cursor-pointer">
              <input
                type="checkbox"
                name="species[datacomplete]"
                checked={@form[:datacomplete].value}
                class="mt-0.5 rounded border-gray-300 text-gf-maroon focus:ring-gf-maroon"
              />
              <span class="text-sm text-gray-700">
                All sources containing unique information relevant to this gall have been added and are reflected in its associated data. However, filter criteria may not be comprehensive in every field.
              </span>
            </label>

            <%= if @mode == :edit do %>
              <label class="flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  checked={@undescribed}
                  phx-click="toggle_undescribed"
                  class="rounded border-gray-300 text-gf-maroon focus:ring-gf-maroon"
                />
                <span class="text-sm text-gray-700">Undescribed?</span>
              </label>
            <% end %>
          </div>

          <%!-- Action buttons --%>
          <div class="flex justify-between items-center pt-3 border-t border-gray-200">
            <div>
              <%= if @mode == :edit do %>
                <.link
                  navigate={~p"/gall/#{@gall.id}"}
                  class="text-sm text-gf-maroon hover:underline"
                >
                  View public page
                </.link>
              <% end %>
            </div>
            <div class="flex gap-2">
              <button
                type="button"
                phx-click="request_cancel"
                class="px-4 py-2 text-sm text-gray-600 hover:text-gray-800"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={not @form_dirty}
                class={[
                  "px-4 py-2 text-sm rounded",
                  if(@form_dirty,
                    do: "bg-gf-maroon text-white hover:bg-gf-maroon/90",
                    else: "bg-gray-300 text-gray-500 cursor-not-allowed"
                  )
                ]}
              >
                {if @mode == :new, do: "Create", else: "Save"}
              </button>
            </div>
          </div>
        </.form>

        <.discard_confirm_modal show={@show_discard_confirm} />
      </Layouts.admin_edit_layout>

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
                <h3 class="text-xl font-semibold text-gray-900">Edit Gall Name</h3>
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
