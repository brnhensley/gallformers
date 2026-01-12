defmodule GallformersWeb.FilterGuideLive do
  @moduledoc """
  LiveView for the filter guide page.

  Displays explanations for all filter terms used in the ID tool.
  """
  use GallformersWeb, :live_view

  alias Gallformers.IDTool

  @impl true
  def mount(_params, _session, socket) do
    filter_fields = %{
      alignment:
        IDTool.list_alignments() |> Enum.map(&%{field: &1.alignment, description: &1.description}),
      cells: IDTool.list_cells() |> Enum.map(&%{field: &1.cells, description: &1.description}),
      form: IDTool.list_forms() |> Enum.map(&%{field: &1.form, description: &1.description}),
      location:
        IDTool.list_locations() |> Enum.map(&%{field: &1.location, description: &1.description}),
      shape: IDTool.list_shapes() |> Enum.map(&%{field: &1.shape, description: &1.description}),
      texture:
        IDTool.list_textures() |> Enum.map(&%{field: &1.texture, description: &1.description}),
      walls: IDTool.list_walls() |> Enum.map(&%{field: &1.walls, description: &1.description})
    }

    {:ok,
     assign(socket,
       page_title: "Filter Guide | Gallformers",
       filter_fields: filter_fields,
       open_sections: MapSet.new()
     )}
  end

  @impl true
  def handle_event("toggle_section", %{"section" => section}, socket) do
    section_atom = String.to_existing_atom(section)
    open_sections = socket.assigns.open_sections

    new_open_sections =
      if MapSet.member?(open_sections, section_atom) do
        MapSet.delete(open_sections, section_atom)
      else
        MapSet.put(open_sections, section_atom)
      end

    {:noreply, assign(socket, open_sections: new_open_sections)}
  end

  defp section_open?(open_sections, section) do
    MapSet.member?(open_sections, section)
  end

  defp sort_by_field(items) do
    Enum.sort_by(items, & &1.field)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-4xl">
        <h1 class="text-3xl font-bold text-gf-maroon mb-4">ID Tool Filter Guide</h1>
        <p class="text-gray-600 mb-8">
          This guide explains the filter terms used in our gall identification tool.
          Click on each section to expand and see the definitions.
        </p>

        <div class="space-y-4">
          <%!-- Alignment --%>
          <.filter_section
            title="Alignment"
            section={:alignment}
            items={sort_by_field(@filter_fields.alignment)}
            open_sections={@open_sections}
          />

          <%!-- Cells --%>
          <.filter_section
            title="Cells"
            section={:cells}
            items={sort_by_field(@filter_fields.cells)}
            open_sections={@open_sections}
            note="NOTE: If multiple larvae are found in one space, these may be inquilines rather than gall-inducers."
          />

          <%!-- Detachable (hardcoded) --%>
          <div class="bg-white rounded-lg shadow-md overflow-hidden">
            <button
              phx-click="toggle_section"
              phx-value-section="detachable"
              class="w-full px-4 py-3 text-left bg-gray-50 hover:bg-gray-100 flex justify-between items-center"
            >
              <span class="font-semibold text-gray-800">Detachable</span>
              <svg
                class={"w-5 h-5 text-gray-500 transition-transform #{if section_open?(@open_sections, :detachable), do: "rotate-180"}"}
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M19 9l-7 7-7-7"
                />
              </svg>
            </button>
            <%= if section_open?(@open_sections, :detachable) do %>
              <div class="p-4 border-t">
                <ul class="space-y-2">
                  <li class="text-gray-700">
                    <span class="font-medium">Yes</span>
                    - the gall could be removed from the plant without destroying the tissue it's attached to (detachable).
                  </li>
                  <li class="text-gray-700">
                    <span class="font-medium">No</span>
                    - the gall could only be removed from the plant by destroying the tissue it's attached to (integral).
                  </li>
                </ul>
                <p class="mt-4 text-sm text-gray-600 italic">
                  NOTE: Galls that have detachable parts but leave some galled tissue behind (more than a scar
                  or blister), are only detachable in some parts of the season, or may be detachable or not, are
                  included in both terms.
                </p>
              </div>
            <% end %>
          </div>

          <%!-- Forms --%>
          <.filter_section
            title="Forms"
            section={:form}
            items={sort_by_field(@filter_fields.form)}
            open_sections={@open_sections}
          />

          <%!-- Location --%>
          <.filter_section
            title="Location"
            section={:location}
            items={sort_by_field(@filter_fields.location)}
            open_sections={@open_sections}
          />

          <%!-- Shape --%>
          <.filter_section
            title="Shape"
            section={:shape}
            items={sort_by_field(@filter_fields.shape)}
            open_sections={@open_sections}
          />

          <%!-- Texture --%>
          <.filter_section
            title="Texture"
            section={:texture}
            items={sort_by_field(@filter_fields.texture)}
            open_sections={@open_sections}
          />

          <%!-- Walls --%>
          <.filter_section
            title="Walls"
            section={:walls}
            items={sort_by_field(@filter_fields.walls)}
            open_sections={@open_sections}
          />
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :title, :string, required: true
  attr :section, :atom, required: true
  attr :items, :list, required: true
  attr :open_sections, MapSet, required: true
  attr :note, :string, default: nil

  defp filter_section(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow-md overflow-hidden">
      <button
        phx-click="toggle_section"
        phx-value-section={@section}
        class="w-full px-4 py-3 text-left bg-gray-50 hover:bg-gray-100 flex justify-between items-center"
      >
        <span class="font-semibold text-gray-800">{@title}</span>
        <svg
          class={"w-5 h-5 text-gray-500 transition-transform #{if section_open?(@open_sections, @section), do: "rotate-180"}"}
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
        </svg>
      </button>
      <%= if section_open?(@open_sections, @section) do %>
        <div class="p-4 border-t">
          <ul class="space-y-2">
            <%= for item <- @items do %>
              <li class="text-gray-700">
                <span class="font-medium">{item.field}</span>
                <%= if item.description do %>
                  <span>&nbsp;- {item.description}</span>
                <% end %>
              </li>
            <% end %>
          </ul>
          <%= if @note do %>
            <p class="mt-4 text-sm text-gray-600 italic">{@note}</p>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end
