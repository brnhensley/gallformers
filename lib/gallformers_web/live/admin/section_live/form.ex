defmodule GallformersWeb.Admin.SectionLive.Form do
  @moduledoc """
  Admin page for managing species membership in taxonomy sections.

  At `/admin/section` (no ID), shows a section picker. Once a section is
  selected, navigates to `/admin/section/:id` for species mapping.

  Section creation and editing (name, description, parent) is handled by the
  taxonomy form.
  """
  use GallformersWeb, :live_view
  use GallformersWeb.Admin.FormHelpers

  alias Gallformers.Plants
  alias Gallformers.Taxonomy
  alias Gallformers.Taxonomy.TaxonName

  @impl true
  def mount(_params, session, socket) do
    current_user = session["current_user"]

    if connected?(socket), do: Taxonomy.subscribe()

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:page_title, "Section Species")
      |> init_form_state()
      |> assign(:section, nil)
      |> assign(:species, [])
      |> assign(:search_results, [])
      |> assign(:search_query, "")
      |> assign(:section_query, "")
      |> assign(:section_results, [])

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Section Species")
    |> assign(:section, nil)
    |> assign(:species, [])
    |> reset_dirty()
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    section = Taxonomy.get_taxonomy!(id)
    species = Taxonomy.get_species_for_section(section.id)

    socket
    |> assign(:page_title, "Section Species: #{section.name}")
    |> assign(:section, section)
    |> assign(:species, species)
    |> reset_dirty()
  end

  # -- Section picker events (index mode) --

  @impl true
  def handle_event("search_section", %{"value" => query}, socket) do
    results =
      if String.length(query) >= 2 do
        Taxonomy.search_sections(query)
      else
        []
      end

    {:noreply,
     socket
     |> assign(:section_query, query)
     |> assign(:section_results, results)}
  end

  @impl true
  def handle_event("select_section", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/admin/section/#{id}")}
  end

  @impl true
  def handle_event("clear_section", _params, socket) do
    {:noreply,
     socket
     |> assign(:section_query, "")
     |> assign(:section_results, [])}
  end

  # -- Species mapping events (edit mode) --

  @impl true
  def handle_event("search_species", %{"value" => query}, socket) do
    if String.length(query) >= 2 do
      selected_ids = Enum.map(socket.assigns.species, & &1.id)

      results =
        Plants.search_hosts_for_section(query, 20)
        |> Enum.reject(fn s -> s.id in selected_ids end)

      {:noreply,
       socket
       |> assign(:search_results, results)
       |> assign(:search_query, query)}
    else
      {:noreply,
       socket
       |> assign(:search_results, [])
       |> assign(:search_query, query)}
    end
  end

  @impl true
  def handle_event("add_species", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    species_to_add = Enum.find(socket.assigns.search_results, &(&1.id == id))

    if species_to_add do
      new_species = socket.assigns.species ++ [species_to_add]
      genera = new_species |> Enum.map(&extract_genus/1) |> Enum.uniq()

      socket =
        if length(genera) > 1 do
          put_flash(socket, :error, "All species must be from the same genus.")
        else
          socket
          |> assign(:species, new_species)
          |> assign(:search_results, Enum.reject(socket.assigns.search_results, &(&1.id == id)))
          |> mark_dirty()
        end

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_species", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    new_species = Enum.reject(socket.assigns.species, &(&1.id == id))
    {:noreply, socket |> assign(:species, new_species) |> mark_dirty()}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    {:noreply,
     socket
     |> assign(:search_results, [])
     |> assign(:search_query, "")}
  end

  @impl true
  def handle_event("save", _params, socket) do
    species_ids = Enum.map(socket.assigns.species, & &1.id)

    if species_ids == [] do
      {:noreply, put_flash(socket, :error, "At least one species is required.")}
    else
      Taxonomy.update_section_species(socket.assigns.section.id, species_ids)

      {:noreply,
       socket
       |> put_flash(:info, "Section species updated successfully")
       |> reset_dirty()
       |> push_navigate(to: ~p"/admin/section/#{socket.assigns.section.id}")}
    end
  end

  @impl true
  def handle_event(event, params, socket)
      when event in ~w(request_cancel cancel_discard confirm_discard) do
    handle_form_event(event, params, socket)
  end

  # -- PubSub --

  @impl true
  def handle_info({event, _entry}, socket)
      when event in [:taxonomy_created, :taxonomy_updated, :taxonomy_deleted, :section_updated] do
    if socket.assigns.section do
      species = Taxonomy.get_species_for_section(socket.assigns.section.id)
      {:noreply, assign(socket, :species, species)}
    else
      {:noreply, socket}
    end
  end

  def close_form(socket) do
    push_navigate(socket, to: ~p"/admin/section")
  end

  defp extract_genus(%{name: name}) do
    case TaxonName.parse(name).genus do
      "" -> nil
      genus -> genus
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin
      flash={@flash}
      current_user={@current_user}
      page_title={@page_title}
    >
      <:page_title_html :if={@section}>
        Species in Section <em class="font-bold">{@section.name}</em>
        <%= if @section.description && @section.description != "" do %>
          <span class="text-gray-500 font-normal">({@section.description})</span>
        <% end %>
      </:page_title_html>

      <%!-- Section picker (index mode) --%>
      <div :if={!@section} class="max-w-xl mx-auto space-y-6">
        <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
          <p class="text-sm text-blue-800">
            <.icon name="ph-info" class="h-4 w-4 inline mr-1" />
            Select a section to manage its species. Create and edit sections in the <.link
              navigate={~p"/admin/taxonomy"}
              class="underline font-medium"
            >taxonomy admin</.link>.
          </p>
        </div>

        <.typeahead
          id="section-picker"
          label="Section"
          placeholder="Search for a section..."
          search_event="search_section"
          select_event="select_section"
          clear_event="clear_section"
          query={@section_query}
          results={@section_results}
          selected={nil}
          display_fn={fn s -> "#{s.name}#{if s.description, do: " (#{s.description})", else: ""}" end}
        />
      </div>

      <%!-- Species mapping (edit mode) --%>
      <div :if={@section}>
        {render_species_mapping(assigns)}
      </div>
    </Layouts.admin>
    """
  end

  defp render_species_mapping(assigns) do
    ~H"""
    <Layouts.admin_edit_layout
      back_path={~p"/admin/section"}
      back_label="Back to Sections"
      public_url={~p"/section/#{@section.name}"}
    >
      <:quick_links>
        <.link
          href={~p"/admin/taxonomy/#{@section.id}"}
          class="text-sm hover:underline"
        >
          Edit in taxonomy
        </.link>
      </:quick_links>
      <:intro>
        Manage which host plant species belong to this section.
      </:intro>

      <div>
        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 mb-2">
            Species in this Section <span class="text-red-500">*</span>
          </label>

          <%!-- Selected species chips --%>
          <div class="mb-3">
            <%= if @species != [] do %>
              <div class="flex flex-wrap gap-2 p-3 bg-gray-50 rounded-lg border border-gray-200">
                <%= for species <- @species do %>
                  <span class="inline-flex items-center gap-1 px-3 py-1 rounded-full text-sm bg-green-100 text-green-800">
                    <.taxon_name name={species.name} />
                    <button
                      type="button"
                      phx-click="remove_species"
                      phx-value-id={species.id}
                      class="ml-1 text-green-600 hover:text-green-800"
                    >
                      <.icon name="ph-x" class="h-3 w-3" />
                    </button>
                  </span>
                <% end %>
              </div>
            <% else %>
              <p class="text-sm text-gray-500 italic p-3 bg-gray-50 rounded-lg border border-gray-200">
                No species selected. Search below to add host plants.
              </p>
            <% end %>
          </div>

          <%!-- Search input --%>
          <div class="relative">
            <input
              type="text"
              phx-keyup="search_species"
              phx-debounce="300"
              value={@search_query}
              name="query"
              placeholder="Search for host plants to add..."
              class="gf-input w-full"
              autocomplete="off"
            />

            <%!-- Search results dropdown --%>
            <%= if @search_results != [] do %>
              <div class="absolute z-10 w-full mt-1 bg-white border border-gray-200 rounded-lg shadow-lg max-h-60 overflow-y-auto">
                <%= for result <- @search_results do %>
                  <button
                    type="button"
                    phx-click="add_species"
                    phx-value-id={result.id}
                    class="w-full text-left px-4 py-2 hover:bg-gray-100 border-b border-gray-100 last:border-0"
                  >
                    <.taxon_name name={result.name} />
                  </button>
                <% end %>
              </div>
            <% end %>
          </div>

          <p class="mt-2 text-xs text-gray-500">
            All species must be from the same genus. Search by species name and click to add.
          </p>
        </div>

        <%!-- Genus info --%>
        <%= if @species != [] do %>
          <div class="mb-4 p-3 bg-blue-50 border border-blue-200 rounded-lg">
            <p class="text-sm text-blue-800">
              <.icon name="ph-info" class="h-4 w-4 inline mr-1" /> Parent genus:
              <strong>{extract_genus(hd(@species))}</strong>
              (derived from species)
            </p>
          </div>
        <% end %>

        <div class="flex justify-end pt-4 border-t border-gray-200">
          <div class="flex gap-2">
            <button
              type="button"
              phx-click="request_cancel"
              class="gf-btn gf-btn-soft"
            >
              Cancel
            </button>
            <button
              type="button"
              phx-click="save"
              disabled={not @form_dirty}
              class="gf-btn gf-btn-primary"
            >
              Save
            </button>
          </div>
        </div>
      </div>
      <.discard_confirm_modal show={@show_discard_confirm} />
    </Layouts.admin_edit_layout>
    """
  end
end
