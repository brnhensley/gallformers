defmodule GallformersWeb.Admin.RangeDrillDown do
  @moduledoc """
  LiveComponent for the range drill-down panel in the gall-host admin page.

  When a curator clicks a country on the gall range map, this panel slides in
  showing checkboxes for each subdivision. Checked = in range, unchecked = not in range.
  """
  use GallformersWeb, :live_component

  alias Gallformers.Places

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       open: false,
       mode: :country,
       country: nil,
       continent: nil,
       subdivisions: [],
       continent_countries: []
     )}
  end

  @impl true
  def update(%{action: {:open, country}}, socket) do
    host_places = socket.assigns.host_places

    # Only show subdivisions that are in the host range
    subdivisions =
      Places.get_children(country.id)
      |> Enum.filter(&(&1.code in host_places))
      |> Enum.sort_by(& &1.name)

    # Find the continent ancestor for the "up" breadcrumb
    continent =
      Places.get_ancestors(country.id)
      |> Enum.find(&(&1.type == "continent"))

    {:ok,
     assign(socket,
       open: true,
       mode: :country,
       country: country,
       continent: continent,
       subdivisions: subdivisions
     )}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(:id, assigns.id)
      |> assign(:host_places, assigns.host_places)
      |> assign(:omitted_place_ids, assigns.omitted_place_ids)
      |> assign(:all_places, assigns.all_places)
      |> assign(:introduced_codes, MapSet.new(Map.get(assigns, :introduced_range, [])))

    # Precompute omitted codes MapSet for O(1) lookups in template
    omitted_codes =
      assigns.all_places
      |> Enum.filter(&(&1.id in assigns.omitted_place_ids))
      |> MapSet.new(& &1.code)

    {:ok, assign(socket, :omitted_codes, omitted_codes)}
  end

  @impl true
  def handle_event("close", _params, socket) do
    notify_parent(:zoom_out)
    {:noreply, assign(socket, open: false, country: nil)}
  end

  @impl true
  def handle_event("toggle_place", %{"code" => code}, socket) do
    notify_parent({:toggle_place, code})
    {:noreply, socket}
  end

  @impl true
  def handle_event("include_all", _params, socket) do
    codes = Enum.map(socket.assigns.subdivisions, & &1.code)
    notify_parent({:include_all, codes})
    {:noreply, socket}
  end

  @impl true
  def handle_event("exclude_all", _params, socket) do
    codes = Enum.map(socket.assigns.subdivisions, & &1.code)
    notify_parent({:exclude_all, codes})
    {:noreply, socket}
  end

  @impl true
  def handle_event("include_all_continent", _params, socket) do
    codes = continent_leaf_codes(socket)
    notify_parent({:include_all, codes})
    {:noreply, socket}
  end

  @impl true
  def handle_event("exclude_all_continent", _params, socket) do
    codes = continent_leaf_codes(socket)
    notify_parent({:exclude_all, codes})
    {:noreply, socket}
  end

  @impl true
  def handle_event("drill_into_country", %{"code" => code}, socket) do
    host_places = socket.assigns.host_places

    case Enum.find(socket.assigns.continent_countries, &(&1.code == code)) do
      nil ->
        {:noreply, socket}

      country ->
        leaf_ids = Places.leaf_descendant_ids(country.id)

        if leaf_ids == [country.id] do
          # Leaf country: toggle directly
          notify_parent({:toggle_place, code})
          {:noreply, socket}
        else
          # Country with subdivisions: switch to country mode
          subdivisions =
            Places.get_children(country.id)
            |> Enum.filter(&(&1.code in host_places))
            |> Enum.sort_by(& &1.name)

          {:noreply,
           assign(socket,
             mode: :country,
             country: country,
             subdivisions: subdivisions
           )}
        end
    end
  end

  @impl true
  def handle_event("navigate_to_continent", _params, socket) do
    continent = socket.assigns.continent
    host_places_set = MapSet.new(socket.assigns.host_places)

    countries =
      Places.get_children(continent.id)
      |> Enum.filter(fn country ->
        # Country is relevant if it or any of its descendants are in host range
        country.code in host_places_set or
          Enum.any?(host_places_set, &String.starts_with?(&1, "#{country.code}-"))
      end)
      |> Enum.sort_by(& &1.name)

    {:noreply,
     assign(socket,
       mode: :continent,
       continent_countries: countries
     )}
  end

  defp panel_title(%{mode: :continent, continent: continent}) when not is_nil(continent),
    do: continent.name

  defp panel_title(%{country: country}) when not is_nil(country), do: country.name
  defp panel_title(_), do: nil

  # Collect all host range codes that belong to countries in the current continent.
  # For countries with subdivisions, this picks up the subdivision codes (e.g., "US-CA").
  # For leaf countries, it picks up the country code itself (e.g., "BS").
  defp continent_leaf_codes(socket) do
    countries = socket.assigns.continent_countries
    host_places = socket.assigns.host_places

    Enum.filter(host_places, fn code ->
      Enum.any?(countries, fn country ->
        code == country.code or String.starts_with?(code, "#{country.code}-")
      end)
    end)
  end

  defp notify_parent(message) do
    send(self(), {__MODULE__, message})
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.drill_down_panel
        open={@open}
        country_name={panel_title(assigns)}
        on_close="close"
        target={@myself}
      >
        <:header_extra>
          <%!-- Continent breadcrumb (country mode only) --%>
          <button
            :if={@mode == :country && @continent}
            type="button"
            phx-click="navigate_to_continent"
            phx-target={@myself}
            class="flex items-center gap-1 text-xs text-blue-600 hover:text-blue-800 hover:underline mb-2"
          >
            <.icon name="ph-arrow-up" class="h-3 w-3" />
            {@continent.name}
          </button>

          <%= if @mode == :country do %>
            <p class="text-xs text-gray-500 mb-2">
              Check states to include them in this gall's range.
            </p>
            <div class="flex gap-2 mb-3">
              <button
                type="button"
                phx-click="include_all"
                phx-target={@myself}
                class="text-xs text-green-700 hover:text-green-900 underline"
              >
                Select All
              </button>
              <span class="text-xs text-gray-300">|</span>
              <button
                type="button"
                phx-click="exclude_all"
                phx-target={@myself}
                class="text-xs text-red-700 hover:text-red-900 underline"
              >
                Deselect All
              </button>
            </div>
          <% else %>
            <p class="text-xs text-gray-500 mb-2">
              Select countries to include in this gall's range.
            </p>
            <div class="flex gap-2 mb-3">
              <button
                type="button"
                phx-click="include_all_continent"
                phx-target={@myself}
                class="text-xs text-green-700 hover:text-green-900 underline"
              >
                Select All
              </button>
              <span class="text-xs text-gray-300">|</span>
              <button
                type="button"
                phx-click="exclude_all_continent"
                phx-target={@myself}
                class="text-xs text-red-700 hover:text-red-900 underline"
              >
                Deselect All
              </button>
            </div>
          <% end %>
        </:header_extra>

        <%!-- Country mode: subdivision list --%>
        <ul :if={@mode == :country} class="space-y-1">
          <li :for={subdiv <- @subdivisions} class="flex items-center">
            <label class={[
              "flex items-center gap-2 w-full px-2 py-1.5 rounded text-sm cursor-pointer hover:bg-gray-50",
              MapSet.member?(@omitted_codes, subdiv.code) && "bg-red-50",
              !MapSet.member?(@omitted_codes, subdiv.code) && "bg-green-50"
            ]}>
              <input
                type="checkbox"
                checked={!MapSet.member?(@omitted_codes, subdiv.code)}
                phx-click="toggle_place"
                phx-target={@myself}
                phx-value-code={subdiv.code}
                class="rounded border-gray-300 text-green-600 focus:ring-green-500"
              />
              <span>{subdiv.name}</span>
              <span
                :if={MapSet.member?(@introduced_codes, subdiv.code)}
                class="text-xs text-amber-600 font-medium"
                title="Introduced host range"
              >
                intro
              </span>
              <span class="ml-auto text-xs text-gray-400">{subdiv.code}</span>
            </label>
          </li>
        </ul>

        <%!-- Continent mode: country list --%>
        <ul :if={@mode == :continent} class="space-y-1">
          <li :for={country <- @continent_countries} class="flex items-center">
            <button
              type="button"
              phx-click="drill_into_country"
              phx-target={@myself}
              phx-value-code={country.code}
              class={[
                "flex items-center gap-2 w-full px-2 py-1.5 rounded text-sm cursor-pointer hover:bg-gray-50",
                MapSet.member?(@omitted_codes, country.code) && "bg-red-50",
                !MapSet.member?(@omitted_codes, country.code) && "bg-green-50"
              ]}
            >
              <span>{country.name}</span>
              <span class="ml-auto text-xs text-gray-400">{country.code}</span>
            </button>
          </li>
        </ul>
      </.drill_down_panel>
    </div>
    """
  end
end
