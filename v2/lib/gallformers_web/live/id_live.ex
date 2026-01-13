defmodule GallformersWeb.IDLive do
  @moduledoc """
  LiveView for the gall identification tool.

  Allows users to filter galls by various characteristics (host, genus, location,
  color, shape, etc.) with URL-based state preservation for back/forward navigation.
  """
  use GallformersWeb, :live_view

  alias Gallformers.{Hosts, IDTool, Places, Taxonomy}

  # URL parameter keys (short codes for compact URLs)
  @url_params %{
    host: "h",
    genus: "g",
    genus_type: "gt",
    locations: "lo",
    color: "co",
    shape: "sh",
    textures: "te",
    alignment: "al",
    detachable: "de",
    place: "pl",
    family: "fa",
    form: "fo",
    walls: "wa",
    cells: "ce",
    season: "se",
    undescribed: "un"
  }

  @impl true
  def mount(_params, _session, socket) do
    filter_options = IDTool.get_filter_options()
    places = Places.list_places()

    {:ok,
     assign(socket,
       page_title: "ID Tool",
       page_description:
         "Identify plant galls using our interactive tool - filter by host plant, genus, location, morphology, and other characteristics.",
       page_url: "/id",
       page_image: nil,
       page_json_ld: nil,
       page_noindex: true,
       filter_options: filter_options,
       places: places,
       families: [],
       # Current filter selections
       filters: default_filters(),
       # Typeahead state
       host_query: "",
       host_results: [],
       selected_host: nil,
       genus_query: "",
       genus_results: [],
       selected_genus: nil,
       # Multi-select typeahead state
       location_query: "",
       location_focused: false,
       texture_query: "",
       texture_focused: false,
       # Results
       results: [],
       total_count: 0,
       show_advanced: false
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters = parse_url_params(params)
    socket = apply_url_filters(socket, filters, params)
    {:noreply, socket}
  end

  # Parse URL parameters into filter map
  defp parse_url_params(params) do
    %{
      locations: parse_list(params[@url_params.locations]),
      color: parse_int(params[@url_params.color]),
      shape: parse_int(params[@url_params.shape]),
      textures: parse_list(params[@url_params.textures]),
      alignment: parse_int(params[@url_params.alignment]),
      detachable: params[@url_params.detachable],
      place: params[@url_params.place],
      family: parse_int(params[@url_params.family]),
      form: parse_int(params[@url_params.form]),
      walls: parse_int(params[@url_params.walls]),
      cells: parse_int(params[@url_params.cells]),
      season: parse_int(params[@url_params.season]),
      undescribed: params[@url_params.undescribed] == "1"
    }
  end

  defp parse_list(nil), do: []

  defp parse_list(str) when is_binary(str) do
    str
    |> String.split(",")
    |> Enum.map(&parse_int/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_int(nil), do: nil
  defp parse_int(""), do: nil

  defp parse_int(str) when is_binary(str) do
    case Integer.parse(str) do
      {int, ""} -> int
      _ -> nil
    end
  end

  # Apply filters from URL and load host/genus if specified
  defp apply_url_filters(socket, filters, params) do
    # Load host from URL param (decode URL encoding)
    host_name =
      case params[@url_params.host] do
        nil -> nil
        name -> URI.decode(name)
      end

    selected_host =
      if host_name && host_name != "" do
        Hosts.get_host_by_name(host_name)
      else
        nil
      end

    # Load genus from URL param (decode URL encoding)
    genus_name =
      case params[@url_params.genus] do
        nil -> nil
        name -> URI.decode(name)
      end

    genus_type =
      case params[@url_params.genus_type] do
        nil -> "genus"
        type -> URI.decode(type)
      end

    selected_genus =
      if genus_name && genus_name != "" do
        case Taxonomy.get_taxonomy_by_name(genus_name, genus_type) do
          nil -> Taxonomy.get_taxonomy_by_name(genus_name)
          tax -> tax
        end
      else
        nil
      end

    # Load families based on selection
    families = load_families_for_selection(selected_host, selected_genus)

    socket
    |> assign(filters: filters)
    |> assign(selected_host: selected_host)
    |> assign(selected_genus: selected_genus)
    |> assign(families: families)
    |> maybe_load_results()
  end

  # Load families relevant to the current host/genus selection
  defp load_families_for_selection(nil, nil), do: []

  defp load_families_for_selection(host, nil) do
    Taxonomy.list_gall_families_for_host(host.id)
  end

  defp load_families_for_selection(nil, genus) do
    case Taxonomy.get_family_for_genus(genus.id) do
      nil -> []
      family -> [family]
    end
  end

  defp load_families_for_selection(host, _genus) do
    # When both are selected, get families for host (genus family should be in there)
    Taxonomy.list_gall_families_for_host(host.id)
  end

  defp default_filters do
    %{
      locations: [],
      color: nil,
      shape: nil,
      textures: [],
      alignment: nil,
      detachable: nil,
      place: nil,
      family: nil,
      form: nil,
      walls: nil,
      cells: nil,
      season: nil,
      undescribed: false
    }
  end

  # Event handlers

  @impl true
  def handle_event("search_host", %{"value" => query}, socket) do
    results =
      if String.length(query) >= 2 do
        Hosts.search_hosts(query, 10)
      else
        []
      end

    {:noreply, assign(socket, host_query: query, host_results: results)}
  end

  @impl true
  def handle_event("select_host", %{"id" => id_str}, socket) do
    host_id = String.to_integer(id_str)
    host = Hosts.get_host(host_id)

    socket =
      socket
      |> assign(selected_host: host, host_query: "", host_results: [])
      |> push_filter_patch()

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_host", _params, socket) do
    socket =
      socket
      |> assign(selected_host: nil)
      |> push_filter_patch()

    {:noreply, socket}
  end

  @impl true
  def handle_event("search_genus", %{"value" => query}, socket) do
    results =
      if String.length(query) >= 2 do
        Taxonomy.search_genera_and_sections(query, 10)
      else
        []
      end

    {:noreply, assign(socket, genus_query: query, genus_results: results)}
  end

  @impl true
  def handle_event("select_genus", %{"id" => id_str}, socket) do
    genus_id = String.to_integer(id_str)
    genus = Taxonomy.get_taxonomy(genus_id)

    socket =
      socket
      |> assign(selected_genus: genus, genus_query: "", genus_results: [])
      |> push_filter_patch()

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_genus", _params, socket) do
    socket =
      socket
      |> assign(selected_genus: nil)
      |> push_filter_patch()

    {:noreply, socket}
  end

  # Location multi-select handlers
  @impl true
  def handle_event("location_search", %{"value" => query}, socket) do
    {:noreply, assign(socket, location_query: query)}
  end

  @impl true
  def handle_event("location_focus", _params, socket) do
    {:noreply, assign(socket, location_focused: true)}
  end

  @impl true
  def handle_event("location_blur", _params, socket) do
    {:noreply, assign(socket, location_focused: false)}
  end

  @impl true
  def handle_event("location_select", %{"id" => id}, socket) do
    location_id = String.to_integer(id)
    locations = socket.assigns.filters.locations

    new_locations =
      if location_id in locations do
        locations
      else
        [location_id | locations]
      end

    socket =
      socket
      |> update_filter(:locations, new_locations)
      |> assign(location_query: "")
      |> push_filter_patch()

    {:noreply, socket}
  end

  @impl true
  def handle_event("location_remove", %{"id" => id}, socket) do
    location_id = String.to_integer(id)
    new_locations = List.delete(socket.assigns.filters.locations, location_id)

    socket =
      socket
      |> update_filter(:locations, new_locations)
      |> push_filter_patch()

    {:noreply, socket}
  end

  @impl true
  def handle_event("location_clear", _params, socket) do
    socket =
      socket
      |> update_filter(:locations, [])
      |> assign(location_query: "", location_focused: false)
      |> push_filter_patch()

    {:noreply, socket}
  end

  # Texture multi-select handlers
  @impl true
  def handle_event("texture_search", %{"value" => query}, socket) do
    {:noreply, assign(socket, texture_query: query)}
  end

  @impl true
  def handle_event("texture_focus", _params, socket) do
    {:noreply, assign(socket, texture_focused: true)}
  end

  @impl true
  def handle_event("texture_blur", _params, socket) do
    {:noreply, assign(socket, texture_focused: false)}
  end

  @impl true
  def handle_event("texture_select", %{"id" => id}, socket) do
    texture_id = String.to_integer(id)
    textures = socket.assigns.filters.textures

    new_textures =
      if texture_id in textures do
        textures
      else
        [texture_id | textures]
      end

    socket =
      socket
      |> update_filter(:textures, new_textures)
      |> assign(texture_query: "")
      |> push_filter_patch()

    {:noreply, socket}
  end

  @impl true
  def handle_event("texture_remove", %{"id" => id}, socket) do
    texture_id = String.to_integer(id)
    new_textures = List.delete(socket.assigns.filters.textures, texture_id)

    socket =
      socket
      |> update_filter(:textures, new_textures)
      |> push_filter_patch()

    {:noreply, socket}
  end

  @impl true
  def handle_event("texture_clear", _params, socket) do
    socket =
      socket
      |> update_filter(:textures, [])
      |> assign(texture_query: "", texture_focused: false)
      |> push_filter_patch()

    {:noreply, socket}
  end

  @impl true
  def handle_event("change_filter", %{"filter" => filter, "value" => value}, socket) do
    filter_key = String.to_existing_atom(filter)

    parsed_value =
      case filter_key do
        :undescribed -> value == "true"
        :detachable -> if value == "", do: nil, else: value
        :place -> if value == "", do: nil, else: value
        _ -> if value == "", do: nil, else: String.to_integer(value)
      end

    socket =
      socket
      |> update_filter(filter_key, parsed_value)
      |> push_filter_patch()

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_advanced", _params, socket) do
    {:noreply, assign(socket, show_advanced: !socket.assigns.show_advanced)}
  end

  @impl true
  def handle_event("clear_all", _params, socket) do
    socket =
      socket
      |> assign(
        filters: default_filters(),
        selected_host: nil,
        selected_genus: nil,
        families: []
      )
      |> push_filter_patch()

    {:noreply, socket}
  end

  defp update_filter(socket, key, value) do
    filters = Map.put(socket.assigns.filters, key, value)
    assign(socket, filters: filters)
  end

  # Build URL parameters and push patch to update URL
  defp push_filter_patch(socket) do
    params = build_url_params(socket)
    push_patch(socket, to: ~p"/id?#{params}")
  end

  defp build_url_params(socket) do
    params = %{}
    filters = socket.assigns.filters

    params =
      if socket.assigns.selected_host do
        Map.put(params, @url_params.host, socket.assigns.selected_host.name)
      else
        params
      end

    params =
      if socket.assigns.selected_genus do
        params
        |> Map.put(@url_params.genus, socket.assigns.selected_genus.name)
        |> Map.put(@url_params.genus_type, socket.assigns.selected_genus.type)
      else
        params
      end

    params = maybe_add_list_param(params, @url_params.locations, filters.locations)
    params = maybe_add_param(params, @url_params.color, filters.color)
    params = maybe_add_param(params, @url_params.shape, filters.shape)
    params = maybe_add_list_param(params, @url_params.textures, filters.textures)
    params = maybe_add_param(params, @url_params.alignment, filters.alignment)
    params = maybe_add_param(params, @url_params.detachable, filters.detachable)
    params = maybe_add_param(params, @url_params.place, filters.place)
    params = maybe_add_param(params, @url_params.family, filters.family)
    params = maybe_add_param(params, @url_params.form, filters.form)
    params = maybe_add_param(params, @url_params.walls, filters.walls)
    params = maybe_add_param(params, @url_params.cells, filters.cells)
    params = maybe_add_param(params, @url_params.season, filters.season)

    params =
      if filters.undescribed,
        do: Map.put(params, @url_params.undescribed, "1"),
        else: params

    params
  end

  defp maybe_add_param(params, _key, nil), do: params
  defp maybe_add_param(params, key, value), do: Map.put(params, key, value)

  defp maybe_add_list_param(params, _key, []), do: params

  defp maybe_add_list_param(params, key, values) do
    Map.put(params, key, Enum.join(values, ","))
  end

  # Load results if host or genus is selected
  defp maybe_load_results(socket) do
    if socket.assigns.selected_host || socket.assigns.selected_genus do
      load_results(socket)
    else
      assign(socket, results: [])
    end
  end

  defp load_results(socket) do
    filter_params = build_filter_params(socket)
    results = IDTool.filter_galls(filter_params)

    if socket.assigns.filters == default_filters() do
      assign(socket, results: results, total_count: length(results))
    else
      assign(socket, results: results)
    end
  end

  defp build_filter_params(socket) do
    filters = socket.assigns.filters

    %{
      host_ids: wrap_in_list(socket.assigns.selected_host, & &1.id),
      genus_id: maybe_get(socket.assigns.selected_genus, :id),
      location_ids: non_empty_list(filters.locations),
      color_ids: wrap_value(filters.color),
      shape_ids: wrap_value(filters.shape),
      texture_ids: non_empty_list(filters.textures),
      alignment_ids: wrap_value(filters.alignment),
      detachable: parse_detachable(filters.detachable),
      place_codes: wrap_value(filters.place),
      family_id: filters.family,
      form_ids: wrap_value(filters.form),
      walls_ids: wrap_value(filters.walls),
      cells_ids: wrap_value(filters.cells),
      season_ids: wrap_value(filters.season),
      undescribed: filters.undescribed
    }
  end

  defp wrap_in_list(nil, _fun), do: nil
  defp wrap_in_list(value, fun), do: [fun.(value)]

  defp wrap_value(nil), do: nil
  defp wrap_value(value), do: [value]

  defp maybe_get(nil, _key), do: nil
  defp maybe_get(map, key), do: Map.get(map, key)

  defp non_empty_list([]), do: nil
  defp non_empty_list(list), do: list

  defp parse_detachable(nil), do: nil
  defp parse_detachable("integral"), do: 1
  defp parse_detachable("detachable"), do: 2
  defp parse_detachable("both"), do: 3
  defp parse_detachable(_), do: nil

  # Helper for formatting host display with aliases
  defp format_host_display(%{name: name, aliases: aliases}) when is_list(aliases) do
    case aliases do
      [] -> name
      alias_list -> "#{name} (#{Enum.join(alias_list, ", ")})"
    end
  end

  defp format_host_display(%{name: name}), do: name

  # Helper for formatting genus display
  defp format_genus_display(%{name: name, type: type, description: desc}) do
    type_label = if type == "section", do: " [Section]", else: ""
    desc_text = if desc && desc != "", do: " - #{desc}", else: ""
    "#{name}#{type_label}#{desc_text}"
  end

  defp format_genus_display(%{name: name}), do: name

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} fluid>
      <div class="py-4">
        <%!-- Host/Genus Pickers --%>
        <div class="mb-2">
          <div class="grid grid-cols-1 md:grid-cols-11 gap-2 items-end">
            <div class="md:col-span-5">
              <.host_picker
                query={@host_query}
                results={@host_results}
                selected={@selected_host}
              />
            </div>
            <div class="md:col-span-1 text-center text-sm text-gray-500 pb-2">
              OR
            </div>
            <div class="md:col-span-5">
              <.genus_picker
                query={@genus_query}
                results={@genus_results}
                selected={@selected_genus}
              />
            </div>
          </div>
        </div>

        <hr class="border-gray-200 mb-4" />

        <%!-- Filter Panel (only shown when host/genus selected) --%>
        <div :if={@selected_host != nil or @selected_genus != nil} class="mb-2">
          <%!-- Primary Filters (4-column grid) --%>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-3">
            <.multi_select_typeahead
              id="locations"
              name="location"
              label="Location(s) on Plant:"
              placeholder="Locations"
              options={@filter_options.locations}
              selected={@filters.locations}
              option_label={:location}
              query={@location_query}
              focused={@location_focused}
            />
            <.detachable_filter value={@filters.detachable} />
            <.place_filter places={@places} value={@filters.place} />
            <.family_filter families={@families} value={@filters.family} />
          </div>

          <%!-- Advanced Filters Toggle and Clear --%>
          <div class="flex justify-between items-center pt-2">
            <button
              type="button"
              phx-click="toggle_advanced"
              class="text-sm text-gf-maroon hover:underline"
            >
              {if @show_advanced, do: "Hide Advanced Filters", else: "Show Advanced Filters"}
            </button>
            <button
              type="button"
              phx-click="clear_all"
              class="text-sm text-red-600 hover:underline"
            >
              Clear All Filters
            </button>
          </div>

          <%!-- Advanced Filters (Collapsible) --%>
          <div :if={@show_advanced} class="border-t border-gray-200 pt-3 mt-3">
            <p class="text-sm text-gray-500 italic mb-3">
              Be aware that many galls do not have associated information for all of the below properties.
            </p>

            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-3">
              <.season_filter options={@filter_options.seasons} value={@filters.season} />
              <.multi_select_typeahead
                id="textures"
                name="texture"
                label="Texture(s):"
                placeholder="Textures"
                options={@filter_options.textures}
                selected={@filters.textures}
                option_label={:texture}
                query={@texture_query}
                focused={@texture_focused}
              />
              <.alignment_filter options={@filter_options.alignments} value={@filters.alignment} />
              <.form_filter options={@filter_options.forms} value={@filters.form} />
              <.walls_filter options={@filter_options.walls} value={@filters.walls} />
              <.cells_filter options={@filter_options.cells} value={@filters.cells} />
              <.shape_filter options={@filter_options.shapes} value={@filters.shape} />
              <.color_filter options={@filter_options.colors} value={@filters.color} />
            </div>

            <div class="mt-3">
              <.undescribed_filter value={@filters.undescribed} />
            </div>
          </div>
        </div>

        <hr class="border-gray-200 my-3" />

        <%!-- Results Grid --%>
        <.results_grid
          results={@results}
          total_count={@total_count}
          has_selection={@selected_host != nil or @selected_genus != nil}
          selected_host={@selected_host}
        />
      </div>
    </Layouts.app>
    """
  end

  # Component: Host Picker Typeahead
  attr :query, :string, required: true
  attr :results, :list, required: true
  attr :selected, :any, required: true

  defp host_picker(assigns) do
    ~H"""
    <div>
      <label class="block text-base font-medium text-gray-700 mb-1">Host:</label>
      <%= if @selected do %>
        <div class="flex items-center gap-2 p-2 bg-gray-50 rounded border">
          <span class="flex-1 text-base italic">{@selected.name}</span>
          <button
            type="button"
            phx-click="clear_host"
            class="text-gray-400 hover:text-gray-600"
            aria-label="Clear host selection"
          >
            <.icon name="hero-x-mark" class="size-4" />
          </button>
        </div>
      <% else %>
        <div class="relative">
          <input
            type="text"
            value={@query}
            phx-keyup="search_host"
            phx-debounce="200"
            placeholder="Search hosts..."
            class="w-full px-3 py-2 border border-gray-300 rounded-md text-base focus:ring-gf-maroon focus:border-gf-maroon"
          />
          <div
            :if={length(@results) > 0}
            class="absolute z-10 w-full mt-1 bg-white border border-gray-200 rounded-md shadow-lg max-h-60 overflow-auto"
          >
            <button
              :for={host <- @results}
              type="button"
              phx-click="select_host"
              phx-value-id={host.id}
              class="w-full text-left px-3 py-2 text-base hover:bg-gray-50 border-b border-gray-100 last:border-b-0"
            >
              <span class="italic">{format_host_display(host)}</span>
              <span :if={!host.datacomplete} class="ml-2 text-xs text-yellow-600">
                (incomplete)
              </span>
            </button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Component: Genus Picker Typeahead
  attr :query, :string, required: true
  attr :results, :list, required: true
  attr :selected, :any, required: true

  defp genus_picker(assigns) do
    ~H"""
    <div>
      <label class="block text-base font-medium text-gray-700 mb-1">Genus / Section:</label>
      <%= if @selected do %>
        <div class="flex items-center gap-2 p-2 bg-gray-50 rounded border">
          <span class="flex-1 text-base italic">{format_genus_display(@selected)}</span>
          <button
            type="button"
            phx-click="clear_genus"
            class="text-gray-400 hover:text-gray-600"
            aria-label="Clear genus selection"
          >
            <.icon name="hero-x-mark" class="size-4" />
          </button>
        </div>
      <% else %>
        <div class="relative">
          <input
            type="text"
            value={@query}
            phx-keyup="search_genus"
            phx-debounce="200"
            placeholder="Search genera..."
            class="w-full px-3 py-2 border border-gray-300 rounded-md text-base focus:ring-gf-maroon focus:border-gf-maroon"
          />
          <div
            :if={length(@results) > 0}
            class="absolute z-10 w-full mt-1 bg-white border border-gray-200 rounded-md shadow-lg max-h-60 overflow-auto"
          >
            <button
              :for={genus <- @results}
              type="button"
              phx-click="select_genus"
              phx-value-id={genus.id}
              class="w-full text-left px-3 py-2 text-base hover:bg-gray-50 border-b border-gray-100 last:border-b-0"
            >
              <span class="italic">{genus.name}</span>
              <span :if={genus.type == "section"} class="ml-1 text-xs text-gray-500">[Section]</span>
              <span :if={genus.description} class="block text-xs text-gray-500 truncate">
                {genus.description}
              </span>
            </button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Component: Detachable Filter
  attr :value, :string, required: true

  defp detachable_filter(assigns) do
    ~H"""
    <div class="mb-2">
      <label class="block text-base font-medium text-gray-700 mb-1">Detachable</label>
      <form phx-change="change_filter" phx-value-filter="detachable">
        <select
          name="value"
          class="w-full px-3 py-2 border border-gray-300 rounded-md text-base focus:ring-gf-maroon focus:border-gf-maroon"
        >
          <option value="" selected={@value == nil}>Any</option>
          <option value="integral" selected={@value == "integral"}>Integral</option>
          <option value="detachable" selected={@value == "detachable"}>Detachable</option>
          <option value="both" selected={@value == "both"}>Both</option>
        </select>
      </form>
    </div>
    """
  end

  # Component: Place Filter
  attr :places, :list, required: true
  attr :value, :string, required: true

  defp place_filter(assigns) do
    ~H"""
    <div class="mb-2">
      <label class="block text-base font-medium text-gray-700 mb-1">Region</label>
      <form phx-change="change_filter" phx-value-filter="place">
        <select
          name="value"
          class="w-full px-3 py-2 border border-gray-300 rounded-md text-base focus:ring-gf-maroon focus:border-gf-maroon"
        >
          <option value="" selected={@value == nil}>Any Region</option>
          <option :for={place <- @places} value={place.code} selected={@value == place.code}>
            {place.name}
          </option>
        </select>
      </form>
    </div>
    """
  end

  # Component: Family Filter
  attr :families, :list, required: true
  attr :value, :integer, required: true

  defp family_filter(assigns) do
    ~H"""
    <div class="mb-2">
      <label class="block text-base font-medium text-gray-700 mb-1">Family</label>
      <form phx-change="change_filter" phx-value-filter="family">
        <select
          name="value"
          class="w-full px-3 py-2 border border-gray-300 rounded-md text-base focus:ring-gf-maroon focus:border-gf-maroon"
        >
          <option value="" selected={@value == nil}>Any Family</option>
          <option :for={fam <- @families} value={fam.id} selected={@value == fam.id}>
            {fam.name}
          </option>
        </select>
      </form>
    </div>
    """
  end

  # Component: Color Filter
  attr :options, :list, required: true
  attr :value, :integer, required: true

  defp color_filter(assigns) do
    ~H"""
    <div class="mb-2">
      <label class="block text-base font-medium text-gray-700 mb-1">Color</label>
      <form phx-change="change_filter" phx-value-filter="color">
        <select
          name="value"
          class="w-full px-3 py-2 border border-gray-300 rounded-md text-base focus:ring-gf-maroon focus:border-gf-maroon"
        >
          <option value="" selected={@value == nil}>Any Color</option>
          <option :for={opt <- @options} value={opt.id} selected={@value == opt.id}>
            {opt.color}
          </option>
        </select>
      </form>
    </div>
    """
  end

  # Component: Shape Filter
  attr :options, :list, required: true
  attr :value, :integer, required: true

  defp shape_filter(assigns) do
    ~H"""
    <div class="mb-2">
      <label class="block text-base font-medium text-gray-700 mb-1">Shape</label>
      <form phx-change="change_filter" phx-value-filter="shape">
        <select
          name="value"
          class="w-full px-3 py-2 border border-gray-300 rounded-md text-base focus:ring-gf-maroon focus:border-gf-maroon"
        >
          <option value="" selected={@value == nil}>Any Shape</option>
          <option :for={opt <- @options} value={opt.id} selected={@value == opt.id}>
            {opt.shape}
          </option>
        </select>
      </form>
    </div>
    """
  end

  # Component: Alignment Filter
  attr :options, :list, required: true
  attr :value, :integer, required: true

  defp alignment_filter(assigns) do
    ~H"""
    <div class="mb-2">
      <label class="block text-base font-medium text-gray-700 mb-1">Alignment</label>
      <form phx-change="change_filter" phx-value-filter="alignment">
        <select
          name="value"
          class="w-full px-3 py-2 border border-gray-300 rounded-md text-base focus:ring-gf-maroon focus:border-gf-maroon"
        >
          <option value="" selected={@value == nil}>Any Alignment</option>
          <option :for={opt <- @options} value={opt.id} selected={@value == opt.id}>
            {opt.alignment}
          </option>
        </select>
      </form>
    </div>
    """
  end

  # Component: Form Filter
  attr :options, :list, required: true
  attr :value, :integer, required: true

  defp form_filter(assigns) do
    ~H"""
    <div class="mb-2">
      <label class="block text-base font-medium text-gray-700 mb-1">Form</label>
      <form phx-change="change_filter" phx-value-filter="form">
        <select
          name="value"
          class="w-full px-3 py-2 border border-gray-300 rounded-md text-base focus:ring-gf-maroon focus:border-gf-maroon"
        >
          <option value="" selected={@value == nil}>Any Form</option>
          <option :for={opt <- @options} value={opt.id} selected={@value == opt.id}>
            {opt.form}
          </option>
        </select>
      </form>
    </div>
    """
  end

  # Component: Walls Filter
  attr :options, :list, required: true
  attr :value, :integer, required: true

  defp walls_filter(assigns) do
    ~H"""
    <div class="mb-2">
      <label class="block text-base font-medium text-gray-700 mb-1">Walls</label>
      <form phx-change="change_filter" phx-value-filter="walls">
        <select
          name="value"
          class="w-full px-3 py-2 border border-gray-300 rounded-md text-base focus:ring-gf-maroon focus:border-gf-maroon"
        >
          <option value="" selected={@value == nil}>Any Walls</option>
          <option :for={opt <- @options} value={opt.id} selected={@value == opt.id}>
            {opt.walls}
          </option>
        </select>
      </form>
    </div>
    """
  end

  # Component: Cells Filter
  attr :options, :list, required: true
  attr :value, :integer, required: true

  defp cells_filter(assigns) do
    ~H"""
    <div class="mb-2">
      <label class="block text-base font-medium text-gray-700 mb-1">Cells</label>
      <form phx-change="change_filter" phx-value-filter="cells">
        <select
          name="value"
          class="w-full px-3 py-2 border border-gray-300 rounded-md text-base focus:ring-gf-maroon focus:border-gf-maroon"
        >
          <option value="" selected={@value == nil}>Any Cells</option>
          <option :for={opt <- @options} value={opt.id} selected={@value == opt.id}>
            {opt.cells}
          </option>
        </select>
      </form>
    </div>
    """
  end

  # Component: Season Filter
  attr :options, :list, required: true
  attr :value, :integer, required: true

  defp season_filter(assigns) do
    ~H"""
    <div class="mb-2">
      <label class="block text-base font-medium text-gray-700 mb-1">Season</label>
      <form phx-change="change_filter" phx-value-filter="season">
        <select
          name="value"
          class="w-full px-3 py-2 border border-gray-300 rounded-md text-base focus:ring-gf-maroon focus:border-gf-maroon"
        >
          <option value="" selected={@value == nil}>Any Season</option>
          <option :for={opt <- @options} value={opt.id} selected={@value == opt.id}>
            {opt.season}
          </option>
        </select>
      </form>
    </div>
    """
  end

  # Component: Undescribed Filter
  attr :value, :boolean, required: true

  defp undescribed_filter(assigns) do
    ~H"""
    <div class="mb-2">
      <form phx-change="change_filter" phx-value-filter="undescribed">
        <label class="flex items-center gap-2 text-base cursor-pointer">
          <input type="hidden" name="value" value="false" />
          <input
            type="checkbox"
            name="value"
            value="true"
            checked={@value}
            class="h-4 w-4 text-gf-maroon focus:ring-gf-maroon border-gray-300 rounded"
          />
          <span class="text-gray-700">Show only undescribed galls</span>
        </label>
      </form>
    </div>
    """
  end

  # Component: Results Grid
  attr :results, :list, required: true
  attr :has_selection, :boolean, required: true
  attr :selected_host, :any, required: true
  attr :total_count, :integer, required: true

  defp results_grid(assigns) do
    ~H"""
    <div>
      <%= if !@has_selection do %>
        <div class="text-center py-8 text-gray-500 bg-blue-50 rounded border border-blue-200">
          <p class="text-sm">
            Select a Host or Genus to see matching galls. Then you can use the filters to narrow down the list.
          </p>
        </div>
      <% else %>
        <%= if @selected_host && !@selected_host.datacomplete do %>
          <div class="mb-3 p-2 bg-yellow-50 border border-yellow-200 rounded text-sm text-yellow-800">
            This host does not yet have all known galls added to the database.
          </div>
        <% end %>

        <p class="text-sm text-gray-600 mb-3">
          Showing <span class="font-semibold">{length(@results)}</span>
          <span :if={length(@results) != @total_count}>of {@total_count}</span> galls:
        </p>

        <%= if length(@results) == 0 do %>
          <div class="p-4 bg-blue-50 border border-blue-200 rounded text-sm">
            <p>
              There are no galls that match your filter. It's possible there are no described species that fit this set of traits and your gall is undescribed.
            </p>
            <p class="mt-2">
              However, before giving up, try <.link
                href="/ref/IDGuide#troubleshooting"
                class="text-gf-maroon underline"
              >altering your filter choices</.link>.
            </p>
          </div>
        <% else %>
          <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-3">
            <.gall_card :for={gall <- @results} gall={gall} />
          </div>
          <div class="mt-4 p-3 bg-blue-50 border border-blue-200 rounded text-sm">
            <p>
              If none of these results match your gall, you may have found an undescribed species. However, before concluding that your gall is not in the database, try <.link
                href="/ref/IDGuide#troubleshooting"
                class="text-gf-maroon underline"
              >altering your filter choices</.link>.
            </p>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  # Component: Individual Gall Card
  attr :gall, :map, required: true

  defp gall_card(assigns) do
    ~H"""
    <.link href={"/gall/#{@gall.id}"} class="block group">
      <div class="bg-white border border-gray-200 rounded-lg overflow-hidden hover:shadow-md transition-shadow">
        <div class="aspect-square bg-gray-100">
          <img
            src={@gall.image_url || ~p"/images/noimage.jpg"}
            alt={@gall.name}
            class="w-full h-full object-cover"
            loading="lazy"
          />
        </div>
        <div class="p-2">
          <p class="text-sm font-medium text-gray-900 group-hover:text-gf-maroon truncate italic">
            {@gall.name}
          </p>
          <div class="flex gap-1 mt-1">
            <span
              :if={@gall.undescribed}
              class="inline-flex items-center px-1.5 py-0.5 text-xs font-medium rounded bg-red-100 text-red-700"
            >
              Undescribed
            </span>
          </div>
        </div>
      </div>
    </.link>
    """
  end
end
