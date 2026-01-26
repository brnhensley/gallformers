defmodule GallformersWeb.IDLive do
  @moduledoc """
  LiveView for the gall identification tool.

  Allows users to filter galls by various characteristics (host, genus, location,
  color, shape, etc.) with URL-based state preservation for back/forward navigation.
  """
  use GallformersWeb, :live_view

  alias Gallformers.{GallSummary, Hosts, IDTool, Places, Taxonomy}

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
       summaries: %{},
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
    selected_host = load_host_from_params(params)
    selected_genus = load_genus_from_params(params)
    families = load_families_for_selection(selected_host, selected_genus)

    socket
    |> assign(filters: filters)
    |> assign(selected_host: selected_host)
    |> assign(selected_genus: selected_genus)
    |> assign(families: families)
    |> maybe_load_results()
  end

  defp load_host_from_params(params) do
    case decode_url_param(params[@url_params.host]) do
      nil -> nil
      "" -> nil
      name -> Hosts.get_host_by_name(name)
    end
  end

  defp load_genus_from_params(params) do
    case decode_url_param(params[@url_params.genus]) do
      nil -> nil
      "" -> nil
      name -> find_genus_by_name(name, params)
    end
  end

  defp find_genus_by_name(name, params) do
    genus_type = decode_url_param(params[@url_params.genus_type]) || "genus"

    case Taxonomy.get_taxonomy_by_name(name, genus_type) do
      nil -> Taxonomy.get_taxonomy_by_name(name)
      tax -> tax
    end
  end

  defp decode_url_param(nil), do: nil
  defp decode_url_param(value), do: URI.decode(value)

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
      |> assign(
        selected_host: host,
        host_query: "",
        host_results: [],
        # Clear genus when selecting host (mutually exclusive)
        selected_genus: nil,
        genus_query: "",
        genus_results: []
      )
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
      |> assign(
        selected_genus: genus,
        genus_query: "",
        genus_results: [],
        # Clear host when selecting genus (mutually exclusive)
        selected_host: nil,
        host_query: "",
        host_results: []
      )
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

  # Valid filter keys from @url_params
  @valid_filter_keys ~w(host genus genus_type locations color shape textures alignment detachable place family form walls cells season undescribed)

  @impl true
  def handle_event("change_filter", %{"filter" => filter, "value" => value}, socket)
      when filter in @valid_filter_keys do
    filter_key = String.to_atom(filter)

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
      assign(socket, results: [], summaries: %{})
    end
  end

  defp load_results(socket) do
    filter_params = build_filter_params(socket)
    results = IDTool.filter_galls(filter_params)

    # Generate summaries for galls without images
    summaries = generate_summaries_for_imageless(results)

    if socket.assigns.filters == default_filters() do
      assign(socket, results: results, summaries: summaries, total_count: length(results))
    else
      assign(socket, results: results, summaries: summaries)
    end
  end

  defp generate_summaries_for_imageless(results) do
    # Find galls without images
    gall_ids_without_images =
      results
      |> Enum.filter(&is_nil(&1.image_url))
      |> Enum.map(& &1.gall_id)

    if Enum.empty?(gall_ids_without_images) do
      %{}
    else
      # Fetch summary data and generate summaries
      summary_data = IDTool.get_summary_data(gall_ids_without_images)

      summary_data
      |> Enum.map(fn {gall_id, filters} ->
        {gall_id, GallSummary.generate(filters, mode: :medium)}
      end)
      |> Enum.into(%{})
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
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="py-4">
        <%!-- Host/Genus Pickers --%>
        <div class="mb-2">
          <div class="grid grid-cols-1 md:grid-cols-11 gap-2 items-end">
            <div class="md:col-span-5">
              <.typeahead
                id="host-picker"
                label="Host:"
                placeholder="Search hosts..."
                query={@host_query}
                results={@host_results}
                selected={@selected_host}
                search_event="search_host"
                select_event="select_host"
                clear_event="clear_host"
                display_fn={&format_host_display/1}
              >
                <:result :let={host}>
                  <span class="italic">{format_host_display(host)}</span>
                  <span :if={!host.datacomplete} class="ml-2 text-xs text-yellow-600">
                    (incomplete)
                  </span>
                </:result>
              </.typeahead>
            </div>
            <div class="md:col-span-1 text-center text-sm text-gray-500 pb-2">
              OR
            </div>
            <div class="md:col-span-5">
              <.typeahead
                id="genus-picker"
                label="Genus / Section:"
                placeholder="Search genera..."
                query={@genus_query}
                results={@genus_results}
                selected={@selected_genus}
                search_event="search_genus"
                select_event="select_genus"
                clear_event="clear_genus"
                display_fn={&format_genus_display/1}
              >
                <:result :let={genus}>
                  <span class="italic">{genus.name}</span>
                  <span :if={genus.type == "section"} class="ml-1 text-xs text-gray-500">
                    [Section]
                  </span>
                  <span :if={genus.description} class="block text-xs text-gray-500 truncate">
                    {genus.description}
                  </span>
                </:result>
              </.typeahead>
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
              class="text-sm hover:underline"
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
          summaries={@summaries}
          total_count={@total_count}
          has_selection={@selected_host != nil or @selected_genus != nil}
          selected_host={@selected_host}
        />
      </div>
    </Layouts.app>
    """
  end

  # Component: Detachable Filter
  attr :value, :string, required: true

  defp detachable_filter(assigns) do
    ~H"""
    <form phx-change="change_filter" phx-value-filter="detachable">
      <.input
        type="select"
        name="value"
        label="Detachable"
        prompt="Any"
        options={[{"Integral", "integral"}, {"Detachable", "detachable"}, {"Both", "both"}]}
        value={@value}
      />
    </form>
    """
  end

  # Component: Place Filter
  attr :places, :list, required: true
  attr :value, :string, required: true

  defp place_filter(assigns) do
    ~H"""
    <form phx-change="change_filter" phx-value-filter="place">
      <.input
        type="select"
        name="value"
        label="Region"
        prompt="Any Region"
        options={Enum.map(@places, &{&1.name, &1.code})}
        value={@value}
      />
    </form>
    """
  end

  # Component: Family Filter
  attr :families, :list, required: true
  attr :value, :integer, required: true

  defp family_filter(assigns) do
    ~H"""
    <form phx-change="change_filter" phx-value-filter="family">
      <.input
        type="select"
        name="value"
        label="Family"
        prompt="Any Family"
        options={Enum.map(@families, &{&1.name, &1.id})}
        value={@value}
      />
    </form>
    """
  end

  # Component: Color Filter
  attr :options, :list, required: true
  attr :value, :integer, required: true

  defp color_filter(assigns) do
    ~H"""
    <form phx-change="change_filter" phx-value-filter="color">
      <.input
        type="select"
        name="value"
        label="Color"
        prompt="Any Color"
        options={Enum.map(@options, &{&1.color, &1.id})}
        value={@value}
      />
    </form>
    """
  end

  # Component: Shape Filter
  attr :options, :list, required: true
  attr :value, :integer, required: true

  defp shape_filter(assigns) do
    ~H"""
    <form phx-change="change_filter" phx-value-filter="shape">
      <.input
        type="select"
        name="value"
        label="Shape"
        prompt="Any Shape"
        options={Enum.map(@options, &{&1.shape, &1.id})}
        value={@value}
      />
    </form>
    """
  end

  # Component: Alignment Filter
  attr :options, :list, required: true
  attr :value, :integer, required: true

  defp alignment_filter(assigns) do
    ~H"""
    <form phx-change="change_filter" phx-value-filter="alignment">
      <.input
        type="select"
        name="value"
        label="Alignment"
        prompt="Any Alignment"
        options={Enum.map(@options, &{&1.alignment, &1.id})}
        value={@value}
      />
    </form>
    """
  end

  # Component: Form Filter
  attr :options, :list, required: true
  attr :value, :integer, required: true

  defp form_filter(assigns) do
    ~H"""
    <form phx-change="change_filter" phx-value-filter="form">
      <.input
        type="select"
        name="value"
        label="Form"
        prompt="Any Form"
        options={Enum.map(@options, &{&1.form, &1.id})}
        value={@value}
      />
    </form>
    """
  end

  # Component: Walls Filter
  attr :options, :list, required: true
  attr :value, :integer, required: true

  defp walls_filter(assigns) do
    ~H"""
    <form phx-change="change_filter" phx-value-filter="walls">
      <.input
        type="select"
        name="value"
        label="Walls"
        prompt="Any Walls"
        options={Enum.map(@options, &{&1.walls, &1.id})}
        value={@value}
      />
    </form>
    """
  end

  # Component: Cells Filter
  attr :options, :list, required: true
  attr :value, :integer, required: true

  defp cells_filter(assigns) do
    ~H"""
    <form phx-change="change_filter" phx-value-filter="cells">
      <.input
        type="select"
        name="value"
        label="Cells"
        prompt="Any Cells"
        options={Enum.map(@options, &{&1.cells, &1.id})}
        value={@value}
      />
    </form>
    """
  end

  # Component: Season Filter
  attr :options, :list, required: true
  attr :value, :integer, required: true

  defp season_filter(assigns) do
    ~H"""
    <form phx-change="change_filter" phx-value-filter="season">
      <.input
        type="select"
        name="value"
        label="Season"
        prompt="Any Season"
        options={Enum.map(@options, &{&1.season, &1.id})}
        value={@value}
      />
    </form>
    """
  end

  # Component: Undescribed Filter
  attr :value, :boolean, required: true

  defp undescribed_filter(assigns) do
    ~H"""
    <div class="mb-2">
      <form phx-change="change_filter" phx-value-filter="undescribed">
        <.input
          type="checkbox"
          name="value"
          checked={@value}
          label="Show only undescribed galls"
        />
      </form>
    </div>
    """
  end

  # Component: Results Grid
  attr :results, :list, required: true
  attr :summaries, :map, required: true
  attr :has_selection, :boolean, required: true
  attr :selected_host, :any, required: true
  attr :total_count, :integer, required: true

  defp results_grid(assigns) do
    ~H"""
    <div>
      <%= if !@has_selection do %>
        <div class="text-center py-8 text-gray-600 bg-blue-50 rounded border border-blue-200">
          <p class="text-base">
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
                class="underline"
              >altering your filter choices</.link>.
            </p>
          </div>
        <% else %>
          <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-3">
            <.gall_card :for={gall <- @results} gall={gall} summary={@summaries[gall.gall_id]} />
          </div>
          <div class="mt-4 p-3 bg-blue-50 border border-blue-200 rounded text-sm">
            <p>
              If none of these results match your gall, you may have found an undescribed species. However, before concluding that your gall is not in the database, try <.link
                href="/ref/IDGuide#troubleshooting"
                class="underline"
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
  attr :summary, :string, default: nil

  defp gall_card(assigns) do
    ~H"""
    <.link href={"/gall/#{@gall.id}"} class="block group">
      <div class="bg-white border border-gray-200 rounded-lg overflow-hidden hover:shadow-md transition-shadow">
        <div class="aspect-square bg-gray-100">
          <img
            src={@gall.image_url || ~p"/images/noimage.jpg"}
            alt=""
            class={[
              "w-full h-full object-cover",
              !@gall.image_url && "opacity-60"
            ]}
            loading="lazy"
          />
        </div>
        <div class="p-2">
          <p class="text-sm font-medium text-gray-900 group-hover:text-gf-maroon truncate italic">
            {@gall.name}
          </p>
          <p :if={!@gall.image_url && @summary} class="text-xs text-gray-600 mt-1" title={@summary}>
            {@summary}
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
