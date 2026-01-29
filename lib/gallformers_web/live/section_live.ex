defmodule GallformersWeb.SectionLive do
  @moduledoc """
  LiveView for the taxonomic section listing page.

  Displays a section (a subdivision within genus for certain plant genera)
  with its list of species.
  """
  use GallformersWeb, :live_view

  alias Gallformers.Taxonomy

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Integer.parse(id) do
      {section_id, ""} ->
        load_section(socket, section_id)

      _ ->
        {:ok,
         assign(socket,
           page_title: "Section Not Found",
           page_description: "The requested taxonomic section was not found on Gallformers.",
           page_url: nil,
           page_image: nil,
           page_json_ld: nil,
           page_noindex: true,
           section: nil,
           error: "Invalid section ID"
         )}
    end
  end

  defp load_section(socket, section_id) do
    case Taxonomy.get_taxonomy(section_id) do
      nil ->
        {:ok,
         assign(socket,
           page_title: "Section Not Found",
           page_description: "The requested taxonomic section was not found on Gallformers.",
           page_url: nil,
           page_image: nil,
           page_json_ld: nil,
           page_noindex: true,
           section: nil,
           error: "Section not found"
         )}

      section ->
        if section.type != "section" do
          {:ok,
           assign(socket,
             page_title: "Section Not Found",
             page_description: "The requested taxonomic section was not found on Gallformers.",
             page_url: nil,
             page_image: nil,
             page_json_ld: nil,
             page_noindex: true,
             section: nil,
             error: "Not a section"
           )}
        else
          # Get species for this section
          species = Gallformers.Taxonomy.get_species_for_section(section_id)

          {:ok,
           assign(socket,
             page_title: "Section #{section.name}",
             page_description:
               "#{section.name} - A taxonomic section documented on Gallformers with #{length(species)} species.",
             page_url: "/section/#{section_id}",
             page_image: nil,
             page_json_ld: nil,
             page_noindex: false,
             section: section,
             species: species,
             error: nil
           )}
        end
    end
  end

  defp format_full_name(name, description) do
    if description do
      "#{name} (#{description})"
    else
      name
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="mx-auto max-w-7xl">
        <%= if @error do %>
          <div class="bg-red-50 border border-red-200 rounded-lg p-4 text-red-700">{@error}</div>
        <% else %>
          <%= if @section do %>
            <%!-- Header --%>
            <div class="mb-6">
              <div class="flex items-center justify-between mb-2">
                <div class="flex items-center gap-2">
                  <h1 class="text-2xl font-bold text-gf-maroon">
                    {format_full_name(@section.name, @section.description)}
                  </h1>
                  <.link
                    :if={@current_user}
                    href={~p"/admin/taxonomy/#{@section.id}"}
                    class="text-gray-400 hover:text-gf-maroon"
                    title="Edit in admin"
                  >
                    <.icon name="ph-pencil-simple" class="h-5 w-5" />
                  </.link>
                </div>
              </div>
            </div>

            <%!-- Species list --%>
            <div class="mt-6">
              <h2 class="text-lg font-semibold text-gray-800 mb-3">
                Species ({length(@species)})
              </h2>
              <%= if length(@species) > 0 do %>
                <div class="bg-white rounded border border-gray-200 overflow-hidden">
                  <table class="gf-table">
                    <thead>
                      <tr>
                        <th>Species Name</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr :for={species <- @species}>
                        <td>
                          <%!-- Sections are for hosts (plants) --%>
                          <.link
                            href={"/host/#{species.id}"}
                            class="hover:underline"
                          >
                            <em>{species.name}</em>
                          </.link>
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              <% else %>
                <p class="text-gray-500 italic">No species found for this section.</p>
              <% end %>
            </div>
          <% else %>
            <div class="bg-red-50 border border-red-200 rounded-lg p-4 text-red-700">
              Section not found
            </div>
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
