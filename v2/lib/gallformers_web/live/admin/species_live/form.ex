defmodule GallformersWeb.Admin.SpeciesLive.Form do
  @moduledoc """
  Admin form for creating and editing species.

  Includes inline alias editor and host picker components for managing
  associated data without page reloads.
  """
  use GallformersWeb, :live_view

  alias Gallformers.Species
  alias Gallformers.Species.Species, as: SpeciesSchema

  @impl true
  def mount(_params, session, socket) do
    current_user = session["current_user"]

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:page_title, "Species")
      |> assign(:abundances, Species.list_abundances())

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    species = %SpeciesSchema{}
    changeset = Species.change_species(species)

    socket
    |> assign(:page_title, "New Species")
    |> assign(:species, species)
    |> assign(:form, to_form(changeset))
    |> assign(:mode, :new)
    |> assign(:aliases, [])
    |> assign(:hosts, [])
    |> assign(:taxonomy, nil)
    |> assign(:new_alias_name, "")
    |> assign(:new_alias_type, "common name")
    |> assign(:host_search_query, "")
    |> assign(:host_search_results, [])
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    case Species.get_species_for_edit(String.to_integer(id)) do
      nil ->
        socket
        |> put_flash(:error, "Species not found")
        |> push_navigate(to: ~p"/admin/species")

      data ->
        changeset = Species.change_species(data.species)

        socket
        |> assign(:page_title, "Edit Species - #{data.species.name}")
        |> assign(:species, data.species)
        |> assign(:form, to_form(changeset))
        |> assign(:mode, :edit)
        |> assign(:aliases, data.aliases)
        |> assign(:hosts, data.hosts)
        |> assign(:taxonomy, data.taxonomy)
        |> assign(:new_alias_name, "")
        |> assign(:new_alias_type, "common name")
        |> assign(:host_search_query, "")
        |> assign(:host_search_results, [])
    end
  end

  @impl true
  def handle_event("validate", %{"species" => params}, socket) do
    changeset =
      socket.assigns.species
      |> Species.change_species(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"species" => params}, socket) do
    save_species(socket, socket.assigns.mode, params)
  end

  # Alias management events

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
      case Species.create_alias_for_species(socket.assigns.species.id, %{name: name, type: type}) do
        {:ok, _alias} ->
          # Reload aliases
          aliases = Species.get_aliases_for_species(socket.assigns.species.id)

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
    Species.remove_alias_from_species(socket.assigns.species.id, String.to_integer(alias_id))
    aliases = Species.get_aliases_for_species(socket.assigns.species.id)

    {:noreply,
     socket
     |> assign(:aliases, aliases)
     |> put_flash(:info, "Alias removed")}
  end

  # Host picker events

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
  def handle_event("add_host", %{"host-id" => host_id}, socket) do
    case Species.add_host_to_species(socket.assigns.species.id, String.to_integer(host_id)) do
      {:ok, _} ->
        hosts = Gallformers.Hosts.get_hosts_for_gall(socket.assigns.species.id)

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
    hosts = Gallformers.Hosts.get_hosts_for_gall(socket.assigns.species.id)

    {:noreply,
     socket
     |> assign(:hosts, hosts)
     |> put_flash(:info, "Host removed")}
  end

  defp save_species(socket, :new, params) do
    case Species.create_species(params) do
      {:ok, species} ->
        {:noreply,
         socket
         |> put_flash(:info, "Species created successfully")
         |> push_navigate(to: ~p"/admin/species/#{species.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_species(socket, :edit, params) do
    case Species.update_species(socket.assigns.species, params) do
      {:ok, _species} ->
        {:noreply,
         socket
         |> put_flash(:info, "Species updated successfully")
         |> push_navigate(to: ~p"/admin/species")}

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
      <div class="max-w-4xl">
        <%!-- Back link --%>
        <div class="mb-6">
          <.link navigate={~p"/admin/species"} class="text-gf-maroon hover:underline">
            <.icon name="hero-arrow-left" class="h-4 w-4 inline" /> Back to Species
          </.link>
        </div>

        <div class="space-y-6">
          <%!-- Main Species Form Card --%>
          <div class="bg-white shadow rounded-lg overflow-hidden">
            <div class="px-6 py-4 border-b border-gray-200 bg-gray-50">
              <h2 class="text-xl font-semibold text-gf-maroon">
                {if @mode == :new, do: "Add New Species", else: "Edit Species"}
              </h2>
            </div>

            <.form for={@form} id="species-form" phx-change="validate" phx-submit="save" class="p-6">
              <div class="space-y-6">
                <div>
                  <.input
                    field={@form[:name]}
                    type="text"
                    label="Species Name"
                    placeholder="Enter species name (e.g., Andricus quercuscalifornicus)"
                    required
                  />
                  <p class="mt-1 text-sm text-gray-500">
                    Use standard binomial nomenclature (Genus species) when known
                  </p>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div>
                    <.input
                      field={@form[:taxoncode]}
                      type="select"
                      label="Type"
                      options={[
                        {"Gall", "gall"},
                        {"Host (Plant)", "plant"},
                        {"Undetermined", "undetermined"}
                      ]}
                      prompt="Select type"
                      required
                    />
                  </div>
                  <div>
                    <.input
                      field={@form[:abundance_id]}
                      type="select"
                      label="Abundance"
                      options={Enum.map(@abundances, &{&1.abundance, &1.id})}
                      prompt="Select abundance"
                    />
                  </div>
                </div>

                <div class="flex items-center">
                  <.input
                    field={@form[:datacomplete]}
                    type="checkbox"
                    label="Data entry is complete for this species"
                  />
                </div>

                <div class="flex justify-end gap-4 pt-4 border-t border-gray-200">
                  <.link
                    navigate={~p"/admin/species"}
                    class="px-4 py-2 text-sm font-medium text-gray-700 hover:text-gray-900"
                  >
                    Cancel
                  </.link>
                  <button
                    type="submit"
                    class="px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-gf-maroon hover:bg-gf-maroon/90 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gf-maroon"
                  >
                    {if @mode == :new, do: "Create Species", else: "Save Changes"}
                  </button>
                </div>
              </div>
            </.form>
          </div>

          <%!-- Taxonomy Display (read-only for now) --%>
          <%= if @mode == :edit && @taxonomy do %>
            <div class="bg-white shadow rounded-lg overflow-hidden">
              <div class="px-6 py-4 border-b border-gray-200 bg-gray-50">
                <h2 class="text-xl font-semibold text-gf-maroon">Taxonomy</h2>
              </div>
              <div class="p-6">
                <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Family</label>
                    <p class="mt-1 text-gray-900">{@taxonomy.family || "—"}</p>
                  </div>
                  <%= if @taxonomy.section do %>
                    <div>
                      <label class="block text-sm font-medium text-gray-700">Section</label>
                      <p class="mt-1 text-gray-900">{@taxonomy.section}</p>
                    </div>
                  <% end %>
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Genus</label>
                    <p class="mt-1 text-gray-900 italic">{@taxonomy.genus || "—"}</p>
                  </div>
                </div>
                <p class="mt-4 text-sm text-gray-500">
                  <.icon name="hero-information-circle" class="h-4 w-4 inline" />
                  Taxonomy is managed in the
                  <.link navigate={~p"/admin/taxonomy"} class="text-gf-maroon hover:underline">
                    Taxonomy section
                  </.link>
                </p>
              </div>
            </div>
          <% end %>

          <%!-- Aliases Section (edit mode only) --%>
          <%= if @mode == :edit do %>
            <div class="bg-white shadow rounded-lg overflow-hidden">
              <div class="px-6 py-4 border-b border-gray-200 bg-gray-50">
                <h2 class="text-xl font-semibold text-gf-maroon">Aliases & Synonyms</h2>
              </div>
              <div class="p-6 space-y-4">
                <%!-- Existing aliases list --%>
                <%= if @aliases != [] do %>
                  <div class="space-y-2">
                    <div
                      :for={alias_entry <- @aliases}
                      class="flex items-center justify-between py-2 px-3 bg-gray-50 rounded-md"
                    >
                      <div>
                        <span class="font-medium italic">{alias_entry.name}</span>
                        <span class="ml-2 text-sm text-gray-500">({alias_entry.type})</span>
                      </div>
                      <button
                        type="button"
                        phx-click="remove_alias"
                        phx-value-alias-id={alias_entry.id}
                        class="text-red-600 hover:text-red-800 text-sm"
                      >
                        <.icon name="hero-x-mark" class="h-4 w-4" />
                      </button>
                    </div>
                  </div>
                <% else %>
                  <p class="text-gray-500 text-sm">No aliases yet.</p>
                <% end %>

                <%!-- Add new alias form --%>
                <div class="pt-4 border-t border-gray-200">
                  <p class="text-sm font-medium text-gray-700 mb-3">Add new alias</p>
                  <div class="flex gap-3">
                    <div class="flex-1">
                      <input
                        type="text"
                        value={@new_alias_name}
                        placeholder="Alias name"
                        phx-keyup="update_new_alias"
                        phx-value-type={@new_alias_type}
                        class="block w-full rounded-md border-gray-300 shadow-sm focus:border-gf-maroon focus:ring-gf-maroon sm:text-sm"
                      />
                    </div>
                    <div class="w-40">
                      <select
                        phx-change="update_new_alias"
                        phx-value-name={@new_alias_name}
                        class="block w-full rounded-md border-gray-300 shadow-sm focus:border-gf-maroon focus:ring-gf-maroon sm:text-sm"
                      >
                        <%= for {label, value} <- alias_type_options() do %>
                          <option value={value} selected={@new_alias_type == value}>{label}</option>
                        <% end %>
                      </select>
                    </div>
                    <button
                      type="button"
                      phx-click="add_alias"
                      class="inline-flex items-center px-3 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-gf-maroon hover:bg-gf-maroon/90"
                    >
                      <.icon name="hero-plus" class="h-4 w-4" />
                    </button>
                  </div>
                </div>
              </div>
            </div>
          <% end %>

          <%!-- Hosts Section (edit mode only, galls only) --%>
          <%= if @mode == :edit && @species.taxoncode == "gall" do %>
            <div class="bg-white shadow rounded-lg overflow-hidden">
              <div class="px-6 py-4 border-b border-gray-200 bg-gray-50">
                <h2 class="text-xl font-semibold text-gf-maroon">Host Plants</h2>
              </div>
              <div class="p-6 space-y-4">
                <%!-- Existing hosts list --%>
                <%= if @hosts != [] do %>
                  <div class="space-y-2">
                    <div
                      :for={host <- @hosts}
                      class="flex items-center justify-between py-2 px-3 bg-gray-50 rounded-md"
                    >
                      <.link
                        navigate={~p"/host/#{host.host_species_id}"}
                        class="font-medium italic text-gf-maroon hover:underline"
                      >
                        {host.host_name}
                      </.link>
                      <button
                        type="button"
                        phx-click="remove_host"
                        phx-value-relation-id={host.host_relation_id}
                        class="text-red-600 hover:text-red-800 text-sm"
                      >
                        <.icon name="hero-x-mark" class="h-4 w-4" />
                      </button>
                    </div>
                  </div>
                <% else %>
                  <p class="text-gray-500 text-sm">No hosts associated yet.</p>
                <% end %>

                <%!-- Add host search --%>
                <div class="pt-4 border-t border-gray-200">
                  <p class="text-sm font-medium text-gray-700 mb-3">Add host plant</p>
                  <div class="relative">
                    <input
                      type="text"
                      value={@host_search_query}
                      placeholder="Search for host plant..."
                      phx-keyup="search_hosts"
                      phx-debounce="300"
                      class="block w-full rounded-md border-gray-300 shadow-sm focus:border-gf-maroon focus:ring-gf-maroon sm:text-sm"
                    />
                    <%= if @host_search_results != [] do %>
                      <div class="absolute z-10 mt-1 w-full bg-white shadow-lg rounded-md border border-gray-200 max-h-60 overflow-auto">
                        <button
                          :for={host <- @host_search_results}
                          type="button"
                          phx-click="add_host"
                          phx-value-host-id={host.id}
                          class="w-full px-4 py-2 text-left hover:bg-gray-50 flex items-center justify-between"
                        >
                          <span class="italic">{host.name}</span>
                          <.icon name="hero-plus" class="h-4 w-4 text-gray-400" />
                        </button>
                      </div>
                    <% end %>
                  </div>
                  <p class="mt-1 text-xs text-gray-500">
                    Type at least 2 characters to search
                  </p>
                </div>
              </div>
            </div>
          <% end %>

          <%!-- View public page link --%>
          <%= if @mode == :edit do %>
            <div class="flex justify-start">
              <%= if @species.taxoncode == "gall" do %>
                <.link navigate={~p"/gall/#{@species.id}"} class="text-gf-maroon hover:underline">
                  <.icon name="hero-eye" class="h-4 w-4 inline" /> View public page
                </.link>
              <% else %>
                <.link navigate={~p"/host/#{@species.id}"} class="text-gf-maroon hover:underline">
                  <.icon name="hero-eye" class="h-4 w-4 inline" /> View public page
                </.link>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </Layouts.admin>
    """
  end
end
