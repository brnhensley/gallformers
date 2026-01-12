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
    families = Taxonomy.list_gall_families()

    {:ok,
     assign(socket,
       page_title: "ID Tool | Gallformers",
       filter_options: filter_options,
       places: places,
       families: families,
       # Current filter selections
       filters: default_filters(),
       # Typeahead state
       host_query: "",
       host_results: [],
       selected_host: nil,
       genus_query: "",
       genus_results: [],
       selected_genus: nil,
       # Results
       results: [],
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
    # Load host from URL param
    host_name = params[@url_params.host]

    selected_host =
      if host_name && host_name != "" do
        Hosts.get_host_by_name(host_name)
      else
        nil
      end

    # Load genus from URL param
    genus_name = params[@url_params.genus]
    genus_type = params[@url_params.genus_type] || "genus"

    selected_genus =
      if genus_name && genus_name != "" do
        case Taxonomy.get_taxonomy_by_name(genus_name, genus_type) do
          nil -> Taxonomy.get_taxonomy_by_name(genus_name)
          tax -> tax
        end
      else
        nil
      end

    socket
    |> assign(filters: filters)
    |> assign(selected_host: selected_host)
    |> assign(selected_genus: selected_genus)
    |> maybe_load_results()
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
  def handle_event("search_host", %{"query" => query}, socket) do
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
  def handle_event("search_genus", %{"query" => query}, socket) do
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

  @impl true
  def handle_event("toggle_location", %{"value" => value}, socket) do
    location_id = String.to_integer(value)
    locations = socket.assigns.filters.locations

    new_locations =
      if location_id in locations do
        List.delete(locations, location_id)
      else
        [location_id | locations]
      end

    socket =
      socket
      |> update_filter(:locations, new_locations)
      |> push_filter_patch()

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_texture", %{"value" => value}, socket) do
    texture_id = String.to_integer(value)
    textures = socket.assigns.filters.textures

    new_textures =
      if texture_id in textures do
        List.delete(textures, texture_id)
      else
        [texture_id | textures]
      end

    socket =
      socket
      |> update_filter(:textures, new_textures)
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
        selected_genus: nil
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
    assign(socket, results: results)
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
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-7xl">
        <div class="mb-6">
          <h1 class="text-2xl font-bold text-gf-maroon">Gall ID Tool</h1>
          <p class="text-gray-600 mt-1">
            Filter galls by host plant, genus, and various characteristics.
          </p>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-4 gap-6">
          <div class="lg:col-span-1 space-y-4">
            <div class="bg-white rounded-lg border border-gray-200 p-4">
              <h2 class="font-semibold text-gray-900 mb-4">Filters</h2>

              <.host_picker
                query={@host_query}
                results={@host_results}
                selected={@selected_host}
              />

              <.genus_picker
                query={@genus_query}
                results={@genus_results}
                selected={@selected_genus}
              />

              <.location_filter
                options={@filter_options.locations}
                selected={@filters.locations}
              />

              <.detachable_filter value={@filters.detachable} />

              <.place_filter places={@places} value={@filters.place} />

              <.family_filter families={@families} value={@filters.family} />

              <button
                type="button"
                phx-click="toggle_advanced"
                class="w-full text-left text-sm text-gf-maroon hover:underline mb-2"
              >
                {if @show_advanced, do: "Hide", else: "Show"} Advanced Filters
                <.icon
                  name={if @show_advanced, do: "hero-chevron-up", else: "hero-chevron-down"}
                  class="size-4 inline ml-1"
                />
              </button>

              <div :if={@show_advanced} class="space-y-4 border-t border-gray-200 pt-4">
                <.color_filter options={@filter_options.colors} value={@filters.color} />
                <.shape_filter options={@filter_options.shapes} value={@filters.shape} />
                <.texture_filter options={@filter_options.textures} selected={@filters.textures} />
                <.alignment_filter options={@filter_options.alignments} value={@filters.alignment} />
                <.form_filter options={@filter_options.forms} value={@filters.form} />
                <.walls_filter options={@filter_options.walls} value={@filters.walls} />
                <.cells_filter options={@filter_options.cells} value={@filters.cells} />
                <.season_filter options={@filter_options.seasons} value={@filters.season} />
                <.undescribed_filter value={@filters.undescribed} />
              </div>

              <button
                type="button"
                phx-click="clear_all"
                class="w-full mt-4 px-3 py-2 text-sm text-gray-600 border border-gray-300 rounded hover:bg-gray-50"
              >
                Clear All Filters
              </button>
            </div>
          </div>

          <div class="lg:col-span-3">
            <.results_grid
              results={@results}
              has_selection={@selected_host != nil or @selected_genus != nil}
              selected_host={@selected_host}
            />
          </div>
        </div>
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
    <div class="mb-4">
      <label class="block text-sm font-medium text-gray-700 mb-1">Host Plant</label>
      <%= if @selected do %>
        <div class="flex items-center gap-2 p-2 bg-gray-50 rounded border">
          <span class="flex-1 text-sm italic">{@selected.name}</span>
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
            class="w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:ring-gf-maroon focus:border-gf-maroon"
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
              class="w-full text-left px-3 py-2 text-sm hover:bg-gray-50 border-b border-gray-100 last:border-b-0"
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
    <div class="mb-4">
      <label class="block text-sm font-medium text-gray-700 mb-1">Genus / Section</label>
      <%= if @selected do %>
        <div class="flex items-center gap-2 p-2 bg-gray-50 rounded border">
          <span class="flex-1 text-sm italic">{format_genus_display(@selected)}</span>
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
            class="w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:ring-gf-maroon focus:border-gf-maroon"
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
              class="w-full text-left px-3 py-2 text-sm hover:bg-gray-50 border-b border-gray-100 last:border-b-0"
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

  # Component: Location Filter (multi-select)
  attr :options, :list, required: true
  attr :selected, :list, required: true

  defp location_filter(assigns) do
    ~H"""
    <div class="mb-4">
      <label class="block text-sm font-medium text-gray-700 mb-2">Location on Plant</label>
      <div class="flex flex-wrap gap-1">
        <button
          :for={loc <- @options}
          type="button"
          phx-click="toggle_location"
          phx-value-value={loc.id}
          class={[
            "px-2 py-1 text-xs rounded border transition-colors",
            loc.id in @selected && "bg-gf-maroon text-white border-gf-maroon",
            loc.id not in @selected && "bg-white text-gray-700 border-gray-300 hover:border-gf-maroon"
          ]}
        >
          {loc.location}
        </button>
      </div>
    </div>
    """
  end

  # Component: Detachable Filter
  attr :value, :string, required: true

  defp detachable_filter(assigns) do
    ~H"""
    <div class="mb-4">
      <label class="block text-sm font-medium text-gray-700 mb-1">Detachable</label>
      <select
        phx-change="change_filter"
        phx-value-filter="detachable"
        name="value"
        class="w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:ring-gf-maroon focus:border-gf-maroon"
      >
        <option value="" selected={@value == nil}>Any</option>
        <option value="integral" selected={@value == "integral"}>Integral</option>
        <option value="detachable" selected={@value == "detachable"}>Detachable</option>
        <option value="both" selected={@value == "both"}>Both</option>
      </select>
    </div>
    """
  end

  # Component: Place Filter
  attr :places, :list, required: true
  attr :value, :string, required: true

  defp place_filter(assigns) do
    ~H"""
    <div class="mb-4">
      <label class="block text-sm font-medium text-gray-700 mb-1">Region</label>
      <select
        phx-change="change_filter"
        phx-value-filter="place"
        name="value"
        class="w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:ring-gf-maroon focus:border-gf-maroon"
      >
        <option value="" selected={@value == nil}>Any Region</option>
        <option :for={place <- @places} value={place.code} selected={@value == place.code}>
          {place.name}
        </option>
      </select>
    </div>
    """
  end

  # Component: Family Filter
  attr :families, :list, required: true
  attr :value, :integer, required: true

  defp family_filter(assigns) do
    ~H"""
    <div class="mb-4">
      <label class="block text-sm font-medium text-gray-700 mb-1">Family</label>
      <select
        phx-change="change_filter"
        phx-value-filter="family"
        name="value"
        class="w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:ring-gf-maroon focus:border-gf-maroon"
      >
        <option value="" selected={@value == nil}>Any Family</option>
        <option :for={fam <- @families} value={fam.id} selected={@value == fam.id}>
          {fam.name}
        </option>
      </select>
    </div>
    """
  end

  # Component: Color Filter
  attr :options, :list, required: true
  attr :value, :integer, required: true

  defp color_filter(assigns) do
    ~H"""
    <div class="mb-4">
      <label class="block text-sm font-medium text-gray-700 mb-1">Color</label>
      <select
        phx-change="change_filter"
        phx-value-filter="color"
        name="value"
        class="w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:ring-gf-maroon focus:border-gf-maroon"
      >
        <option value="" selected={@value == nil}>Any Color</option>
        <option :for={opt <- @options} value={opt.id} selected={@value == opt.id}>
          {opt.color}
        </option>
      </select>
    </div>
    """
  end

  # Component: Shape Filter
  attr :options, :list, required: true
  attr :value, :integer, required: true

  defp shape_filter(assigns) do
    ~H"""
    <div class="mb-4">
      <label class="block text-sm font-medium text-gray-700 mb-1">Shape</label>
      <select
        phx-change="change_filter"
        phx-value-filter="shape"
        name="value"
        class="w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:ring-gf-maroon focus:border-gf-maroon"
      >
        <option value="" selected={@value == nil}>Any Shape</option>
        <option :for={opt <- @options} value={opt.id} selected={@value == opt.id}>
          {opt.shape}
        </option>
      </select>
    </div>
    """
  end

  # Component: Texture Filter (multi-select)
  attr :options, :list, required: true
  attr :selected, :list, required: true

  defp texture_filter(assigns) do
    ~H"""
    <div class="mb-4">
      <label class="block text-sm font-medium text-gray-700 mb-2">Texture</label>
      <div class="flex flex-wrap gap-1">
        <button
          :for={tex <- @options}
          type="button"
          phx-click="toggle_texture"
          phx-value-value={tex.id}
          class={[
            "px-2 py-1 text-xs rounded border transition-colors",
            tex.id in @selected && "bg-gf-maroon text-white border-gf-maroon",
            tex.id not in @selected && "bg-white text-gray-700 border-gray-300 hover:border-gf-maroon"
          ]}
        >
          {tex.texture}
        </button>
      </div>
    </div>
    """
  end

  # Component: Alignment Filter
  attr :options, :list, required: true
  attr :value, :integer, required: true

  defp alignment_filter(assigns) do
    ~H"""
    <div class="mb-4">
      <label class="block text-sm font-medium text-gray-700 mb-1">Alignment</label>
      <select
        phx-change="change_filter"
        phx-value-filter="alignment"
        name="value"
        class="w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:ring-gf-maroon focus:border-gf-maroon"
      >
        <option value="" selected={@value == nil}>Any Alignment</option>
        <option :for={opt <- @options} value={opt.id} selected={@value == opt.id}>
          {opt.alignment}
        </option>
      </select>
    </div>
    """
  end

  # Component: Form Filter
  attr :options, :list, required: true
  attr :value, :integer, required: true

  defp form_filter(assigns) do
    ~H"""
    <div class="mb-4">
      <label class="block text-sm font-medium text-gray-700 mb-1">Form</label>
      <select
        phx-change="change_filter"
        phx-value-filter="form"
        name="value"
        class="w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:ring-gf-maroon focus:border-gf-maroon"
      >
        <option value="" selected={@value == nil}>Any Form</option>
        <option :for={opt <- @options} value={opt.id} selected={@value == opt.id}>
          {opt.form}
        </option>
      </select>
    </div>
    """
  end

  # Component: Walls Filter
  attr :options, :list, required: true
  attr :value, :integer, required: true

  defp walls_filter(assigns) do
    ~H"""
    <div class="mb-4">
      <label class="block text-sm font-medium text-gray-700 mb-1">Walls</label>
      <select
        phx-change="change_filter"
        phx-value-filter="walls"
        name="value"
        class="w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:ring-gf-maroon focus:border-gf-maroon"
      >
        <option value="" selected={@value == nil}>Any Walls</option>
        <option :for={opt <- @options} value={opt.id} selected={@value == opt.id}>
          {opt.walls}
        </option>
      </select>
    </div>
    """
  end

  # Component: Cells Filter
  attr :options, :list, required: true
  attr :value, :integer, required: true

  defp cells_filter(assigns) do
    ~H"""
    <div class="mb-4">
      <label class="block text-sm font-medium text-gray-700 mb-1">Cells</label>
      <select
        phx-change="change_filter"
        phx-value-filter="cells"
        name="value"
        class="w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:ring-gf-maroon focus:border-gf-maroon"
      >
        <option value="" selected={@value == nil}>Any Cells</option>
        <option :for={opt <- @options} value={opt.id} selected={@value == opt.id}>
          {opt.cells}
        </option>
      </select>
    </div>
    """
  end

  # Component: Season Filter
  attr :options, :list, required: true
  attr :value, :integer, required: true

  defp season_filter(assigns) do
    ~H"""
    <div class="mb-4">
      <label class="block text-sm font-medium text-gray-700 mb-1">Season</label>
      <select
        phx-change="change_filter"
        phx-value-filter="season"
        name="value"
        class="w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:ring-gf-maroon focus:border-gf-maroon"
      >
        <option value="" selected={@value == nil}>Any Season</option>
        <option :for={opt <- @options} value={opt.id} selected={@value == opt.id}>
          {opt.season}
        </option>
      </select>
    </div>
    """
  end

  # Component: Undescribed Filter
  attr :value, :boolean, required: true

  defp undescribed_filter(assigns) do
    ~H"""
    <div class="mb-4">
      <label class="flex items-center gap-2 text-sm">
        <input
          type="checkbox"
          checked={@value}
          phx-click="change_filter"
          phx-value-filter="undescribed"
          phx-value-value={if @value, do: "false", else: "true"}
          class="h-4 w-4 text-gf-maroon focus:ring-gf-maroon border-gray-300 rounded"
        />
        <span class="text-gray-700">Show only undescribed galls</span>
      </label>
    </div>
    """
  end

  # Component: Results Grid
  attr :results, :list, required: true
  attr :has_selection, :boolean, required: true
  attr :selected_host, :any, required: true

  defp results_grid(assigns) do
    ~H"""
    <div class="bg-white rounded-lg border border-gray-200 p-4">
      <%= if !@has_selection do %>
        <div class="text-center py-12 text-gray-500">
          <.icon name="hero-magnifying-glass" class="size-12 mx-auto mb-4 text-gray-300" />
          <p>Select a Host or Genus to begin filtering galls.</p>
        </div>
      <% else %>
        <div class="mb-4 flex items-center justify-between">
          <p class="text-sm text-gray-600">
            Showing <span class="font-semibold">{length(@results)}</span> galls
          </p>
        </div>

        <%= if @selected_host && !@selected_host.datacomplete do %>
          <div class="mb-4 p-3 bg-yellow-50 border border-yellow-200 rounded text-sm text-yellow-800">
            <.icon name="hero-exclamation-triangle" class="size-4 inline mr-1" />
            This host does not yet have all known galls added to the database.
          </div>
        <% end %>

        <%= if length(@results) == 0 do %>
          <div class="text-center py-12 text-gray-500">
            <.icon name="hero-face-frown" class="size-12 mx-auto mb-4 text-gray-300" />
            <p>No galls match your current filters.</p>
            <p class="text-sm mt-2">
              Try removing some filters or check the <.link
                href="/filterguide"
                class="text-gf-maroon hover:underline"
              >filter guide</.link>.
            </p>
          </div>
        <% else %>
          <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
            <.gall_card :for={gall <- @results} gall={gall} />
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
        <%= if @gall.image_url do %>
          <div class="aspect-square bg-gray-100">
            <img
              src={@gall.image_url}
              alt={@gall.name}
              class="w-full h-full object-cover"
              loading="lazy"
            />
          </div>
        <% else %>
          <div class="aspect-square bg-gray-100 flex items-center justify-center">
            <.icon name="hero-photo" class="size-12 text-gray-300" />
          </div>
        <% end %>
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
