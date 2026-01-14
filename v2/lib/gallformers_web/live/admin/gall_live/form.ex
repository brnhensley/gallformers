defmodule GallformersWeb.Admin.GallLive.Form do
  @moduledoc """
  Admin form for creating and editing galls.
  Layout mirrors V1 gall admin for consistency.
  """
  use GallformersWeb, :live_view

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

    {:ok, socket}
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
    |> assign(:filter_search, init_filter_search_state())
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

          socket
          |> assign(:page_title, "Edit Gall - #{species.name}")
          |> assign(:gall, species)
          |> assign(:gall_data, gall_data)
          |> assign(:form, to_form(changeset))
          |> assign(:mode, :edit)
          |> assign(:aliases, aliases)
          |> assign(:hosts, hosts)
          |> assign(:taxonomy, taxonomy)
          |> assign(:filter_values, gall_data.filter_values)
          |> assign(:gall_id, gall_data.gall_id)
          |> assign(:detachable, gall_data.detachable || 0)
          |> assign(:undescribed, gall_data.undescribed || false)
          |> assign(:new_alias_name, "")
          |> assign(:new_alias_type, "common name")
          |> assign(:host_search_query, "")
          |> assign(:host_search_results, [])
          |> assign(:filter_search, init_filter_search_state())
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

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"species" => params}, socket) do
    params = Map.put(params, "taxoncode", "gall")
    save_gall(socket, socket.assigns.mode, params)
  end

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
      case Species.create_alias_for_species(socket.assigns.gall.id, %{name: name, type: type}) do
        {:ok, _alias} ->
          aliases = Species.get_aliases_for_species(socket.assigns.gall.id)

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
    Species.remove_alias_from_species(socket.assigns.gall.id, String.to_integer(alias_id))
    aliases = Species.get_aliases_for_species(socket.assigns.gall.id)

    {:noreply,
     socket
     |> assign(:aliases, aliases)
     |> put_flash(:info, "Alias removed")}
  end

  @impl true
  def handle_event("search_hosts", %{"query" => query}, socket) do
    results =
      if String.length(query) >= 2 do
        Species.search_species_by_name(query, "plant", 10)
      else
        []
      end

    {:noreply, assign(socket, host_search_query: query, host_search_results: results)}
  end

  @impl true
  def handle_event("add_host", %{"id" => host_id}, socket) do
    case Species.add_host_to_species(socket.assigns.gall.id, String.to_integer(host_id)) do
      {:ok, _} ->
        hosts = Gallformers.Hosts.get_hosts_for_gall(socket.assigns.gall.id)

        {:noreply,
         socket
         |> assign(:hosts, hosts)
         |> assign(:host_search_query, "")
         |> assign(:host_search_results, [])
         |> put_flash(:info, "Host added")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add host (may already be associated)")}
    end
  end

  @impl true
  def handle_event("remove_host", %{"relation-id" => relation_id}, socket) do
    Species.remove_host_from_species(String.to_integer(relation_id))
    hosts = Gallformers.Hosts.get_hosts_for_gall(socket.assigns.gall.id)

    {:noreply,
     socket
     |> assign(:hosts, hosts)
     |> put_flash(:info, "Host removed")}
  end

  @impl true
  def handle_event("update_detachable", %{"value" => value}, socket) do
    detachable = String.to_integer(value)

    if socket.assigns.gall_id do
      Species.update_gall_properties(socket.assigns.gall_id, %{detachable: detachable})
    end

    {:noreply, assign(socket, :detachable, detachable)}
  end

  @impl true
  def handle_event("toggle_undescribed", _params, socket) do
    new_value = !socket.assigns.undescribed

    if socket.assigns.gall_id do
      Species.update_gall_properties(socket.assigns.gall_id, %{undescribed: new_value})
    end

    {:noreply, assign(socket, :undescribed, new_value)}
  end

  @impl true
  def handle_event("filter_search", %{"type" => type, "query" => query}, socket) do
    filter_search = Map.put(socket.assigns.filter_search, String.to_atom(type), query)
    {:noreply, assign(socket, :filter_search, filter_search)}
  end

  @impl true
  def handle_event("add_filter", %{"type" => type, "id" => id}, socket) do
    filter_type = String.to_atom(type)
    filter_id = String.to_integer(id)
    gall_id = socket.assigns.gall_id

    if gall_id do
      case Species.add_filter_field_to_gall(gall_id, filter_type, filter_id) do
        {:ok, _} ->
          filter_values = Species.get_gall_filter_values(gall_id)
          filter_search = Map.put(socket.assigns.filter_search, filter_type, "")

          {:noreply,
           socket
           |> assign(:filter_values, filter_values)
           |> assign(:filter_search, filter_search)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to add filter")}
      end
    else
      {:noreply, put_flash(socket, :error, "Save the gall first before adding filters")}
    end
  end

  @impl true
  def handle_event("remove_filter", %{"type" => type, "id" => id}, socket) do
    filter_type = String.to_atom(type)
    filter_id = String.to_integer(id)
    gall_id = socket.assigns.gall_id

    if gall_id do
      Species.remove_filter_field_from_gall(gall_id, filter_type, filter_id)
      filter_values = Species.get_gall_filter_values(gall_id)
      {:noreply, assign(socket, :filter_values, filter_values)}
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
      {:ok, _gall} ->
        {:noreply,
         socket
         |> put_flash(:info, "Gall updated successfully")
         |> push_navigate(to: ~p"/admin/galls")}

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

  defp filter_available_options(options, selected, search_query) do
    selected_ids = MapSet.new(Enum.map(selected, & &1.id))
    search_lower = String.downcase(search_query)

    options
    |> Enum.reject(&MapSet.member?(selected_ids, &1.id))
    |> Enum.filter(fn opt ->
      search_query == "" || String.contains?(String.downcase(opt.field), search_lower)
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} page_title={@page_title}>
      <div class="max-w-7xl mx-auto">
        <div class="mb-4">
          <.link navigate={~p"/admin/galls"} class="text-gf-maroon hover:underline text-sm">
            &larr; Back to Galls
          </.link>
        </div>

        <div class="bg-white border border-gray-200 rounded shadow-sm">
          <div class="px-4 py-3 border-b border-gray-200 bg-gray-50">
            <h4 class="text-lg font-semibold text-gf-maroon">Edit Gallformers</h4>
          </div>

          <div class="p-4">
            <%!-- Intro text with links --%>
            <p class="text-sm text-gray-600 mb-4">
              This is for all of the details about a Gall. To add a description (which must be referenced to a source) go add <.link
                navigate={~p"/admin/sources"}
                class="text-gf-maroon hover:underline"
              >Sources</.link>, if they do not already exist, then go <span class="text-gray-400">map species to sources with description</span>.
              To associate a gall with all plants in a genus, add one species here first, then go to <span class="text-gray-400">Gall-Host Mappings</span>.
            </p>

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
                <label class="block text-sm font-medium text-gray-700 mb-1">Hosts (required):</label>
                <%= if @mode == :edit do %>
                  <div
                    id="host-picker"
                    phx-hook="Typeahead"
                    data-input-id="host-picker-input"
                    class="relative"
                  >
                    <div class="flex flex-wrap gap-1 p-2 border border-gray-300 rounded bg-white min-h-[38px]">
                      <span
                        :for={host <- @hosts}
                        class="inline-flex items-center gap-1 px-2 py-0.5 bg-blue-100 text-blue-800 rounded text-sm"
                      >
                        {host.host_name}
                        <button
                          type="button"
                          phx-click="remove_host"
                          phx-value-relation-id={host.host_relation_id}
                          class="text-blue-600 hover:text-blue-800"
                        >
                          <.icon name="ph-x" class="h-3 w-3" />
                        </button>
                      </span>
                      <input
                        id="host-picker-input"
                        data-typeahead-input
                        type="text"
                        value={@host_search_query}
                        placeholder={if @hosts == [], do: "Search hosts...", else: ""}
                        phx-keyup="search_hosts"
                        phx-debounce="300"
                        class="flex-1 min-w-[120px] border-0 p-0 text-sm focus:ring-0 focus:outline-none"
                      />
                    </div>
                    <%= if @host_search_results != [] do %>
                      <div
                        id="host-search-results"
                        data-typeahead-results
                        class="absolute z-20 mt-1 w-full bg-white shadow-lg rounded border border-gray-200 max-h-48 overflow-auto"
                      >
                        <button
                          :for={host <- @host_search_results}
                          type="button"
                          data-typeahead-option
                          phx-click="add_host"
                          phx-value-id={host.id}
                          class="w-full px-3 py-2 text-left text-sm hover:bg-gray-100"
                        >
                          {host.name}
                        </button>
                      </div>
                    <% end %>
                  </div>
                  <%= if @hosts == [] do %>
                    <p class="text-red-600 text-xs mt-1">
                      You must map this gall to at least one host.
                    </p>
                  <% end %>
                <% else %>
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
                  <.filter_field
                    label="Walls:"
                    type={:walls}
                    options={@filter_options.walls}
                    selected={@filter_values.walls}
                    search_query={@filter_search.walls}
                  />
                  <.filter_field
                    label="Cells:"
                    type={:cells}
                    options={@filter_options.cells}
                    selected={@filter_values.cells}
                    search_query={@filter_search.cells}
                  />
                  <.filter_field
                    label="Alignment(s):"
                    type={:alignments}
                    options={@filter_options.alignments}
                    selected={@filter_values.alignments}
                    search_query={@filter_search.alignments}
                  />
                </div>

                <%!-- Row: Color | Shape | Season | Form --%>
                <div class="grid grid-cols-4 gap-3 mb-3">
                  <.filter_field
                    label="Color(s):"
                    type={:colors}
                    options={@filter_options.colors}
                    selected={@filter_values.colors}
                    search_query={@filter_search.colors}
                  />
                  <.filter_field
                    label="Shape(s):"
                    type={:shapes}
                    options={@filter_options.shapes}
                    selected={@filter_values.shapes}
                    search_query={@filter_search.shapes}
                  />
                  <.filter_field
                    label="Season(s):"
                    type={:seasons}
                    options={@filter_options.seasons}
                    selected={@filter_values.seasons}
                    search_query={@filter_search.seasons}
                  />
                  <.filter_field
                    label="Form(s):"
                    type={:forms}
                    options={@filter_options.forms}
                    selected={@filter_values.forms}
                    search_query={@filter_search.forms}
                  />
                </div>

                <%!-- Row: Location | Texture | Abundance --%>
                <div class="grid grid-cols-3 gap-3 mb-3">
                  <.filter_field
                    label="Location(s):"
                    type={:locations}
                    options={@filter_options.locations}
                    selected={@filter_values.locations}
                    search_query={@filter_search.locations}
                  />
                  <.filter_field
                    label="Texture(s):"
                    type={:textures}
                    options={@filter_options.textures}
                    selected={@filter_values.textures}
                    search_query={@filter_search.textures}
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
                  <.link
                    navigate={~p"/admin/galls"}
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

  # Compact filter field component matching V1 typeahead style
  defp filter_field(assigns) do
    available =
      filter_available_options(assigns.options, assigns.selected, assigns.search_query)

    assigns = assign(assigns, :available, available)

    ~H"""
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-1">{@label}</label>
      <div class="relative">
        <div class="flex flex-wrap gap-1 p-1.5 border border-gray-300 rounded bg-white min-h-[34px]">
          <span
            :for={item <- @selected}
            class="inline-flex items-center gap-0.5 px-1.5 py-0.5 bg-blue-100 text-blue-800 rounded text-xs"
          >
            {item.field}
            <button
              type="button"
              phx-click="remove_filter"
              phx-value-type={@type}
              phx-value-id={item.id}
              class="text-blue-600 hover:text-blue-800"
            >
              <.icon name="ph-x" class="h-3 w-3" />
            </button>
          </span>
          <input
            type="text"
            value={@search_query}
            placeholder={if @selected == [], do: "Select...", else: ""}
            phx-keyup="filter_search"
            phx-value-type={@type}
            class="flex-1 min-w-[60px] border-0 p-0 text-xs focus:ring-0 focus:outline-none"
          />
        </div>
        <%= if @search_query != "" && @available != [] do %>
          <div class="absolute z-20 mt-1 w-full bg-white shadow-lg rounded border border-gray-200 max-h-32 overflow-auto">
            <button
              :for={opt <- Enum.take(@available, 8)}
              type="button"
              phx-click="add_filter"
              phx-value-type={@type}
              phx-value-id={opt.id}
              class="w-full px-2 py-1 text-left text-xs hover:bg-gray-100"
            >
              {opt.field}
            </button>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
