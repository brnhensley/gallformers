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
           page_title: "Section Not Found | Gallformers",
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
           page_title: "Section Not Found | Gallformers",
           section: nil,
           error: "Section not found"
         )}

      section ->
        if section.type != "section" do
          {:ok,
           assign(socket,
             page_title: "Section Not Found | Gallformers",
             section: nil,
             error: "Not a section"
           )}
        else
          # Get species for this section
          species = get_species_for_section(section_id)

          {:ok,
           assign(socket,
             page_title: "Section #{section.name} | Gallformers",
             section: section,
             species: species,
             error: nil
           )}
        end
    end
  end

  defp get_species_for_section(section_id) do
    import Ecto.Query
    alias Gallformers.Repo
    alias Gallformers.Species.Species

    from(s in Species,
      join: st in "speciestaxonomy",
      on: st.species_id == s.id,
      where: st.taxonomy_id == ^section_id,
      order_by: s.name,
      select: %{
        id: s.id,
        name: s.name,
        taxoncode: s.taxoncode
      }
    )
    |> Repo.all()
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
                <h1 class="text-2xl font-bold text-gf-maroon">
                  {format_full_name(@section.name, @section.description)}
                </h1>
              </div>
            </div>

            <%!-- Species list --%>
            <div class="mt-6">
              <h2 class="text-lg font-semibold text-gray-800 mb-3">
                Species ({length(@species)})
              </h2>
              <%= if length(@species) > 0 do %>
                <div class="bg-white rounded border border-gray-200">
                  <table class="min-w-full divide-y divide-gray-200">
                    <thead class="bg-gray-50">
                      <tr>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Species Name
                        </th>
                      </tr>
                    </thead>
                    <tbody class="bg-white divide-y divide-gray-200">
                      <%= for species <- @species do %>
                        <tr class="hover:bg-gray-50">
                          <td class="px-6 py-4 whitespace-nowrap text-sm">
                            <%!-- Sections are for hosts (plants) --%>
                            <.link
                              href={"/host/#{species.id}"}
                              class="text-gf-maroon hover:underline"
                            >
                              <em>{species.name}</em>
                            </.link>
                          </td>
                        </tr>
                      <% end %>
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
