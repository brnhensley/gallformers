defmodule GallformersWeb.GenusLive do
  @moduledoc """
  LiveView for the taxonomic genus listing page.

  Displays a genus with its parent family and list of species.
  """
  use GallformersWeb, :live_view

  alias Gallformers.Taxonomy

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Integer.parse(id) do
      {genus_id, ""} ->
        load_genus(socket, genus_id)

      _ ->
        {:ok,
         assign(socket,
           page_title: "Genus Not Found",
           page_description: "The requested taxonomic genus was not found on Gallformers.",
           page_url: nil,
           page_image: nil,
           page_json_ld: nil,
           page_noindex: true,
           genus: nil,
           error: "Invalid genus ID"
         )}
    end
  end

  defp load_genus(socket, genus_id) do
    case Taxonomy.get_taxonomy(genus_id) do
      nil ->
        {:ok, assign_genus_not_found(socket, "Genus not found")}

      %{type: "genus"} = genus ->
        {:ok, assign_genus_data(socket, genus, genus_id)}

      _not_a_genus ->
        {:ok, assign_genus_not_found(socket, "Not a genus")}
    end
  end

  defp assign_genus_not_found(socket, error) do
    assign(socket,
      page_title: "Genus Not Found",
      page_description: "The requested taxonomic genus was not found on Gallformers.",
      page_url: nil,
      page_image: nil,
      page_json_ld: nil,
      page_noindex: true,
      genus: nil,
      error: error
    )
  end

  defp assign_genus_data(socket, genus, genus_id) do
    family = if genus.parent_id, do: Taxonomy.get_taxonomy(genus.parent_id), else: nil
    species_ids = Taxonomy.get_species_ids_for_genus(genus_id)
    species = if species_ids == [], do: [], else: get_species_info(species_ids)

    assign(socket,
      page_title: "Genus #{genus.name}",
      page_description:
        "#{genus.name} - A taxonomic genus documented on Gallformers with #{length(species)} species.",
      page_url: "/genus/#{genus_id}",
      page_image: nil,
      page_json_ld: nil,
      page_noindex: false,
      genus: genus,
      family: family,
      species: species,
      error: nil
    )
  end

  defp get_species_info(species_ids) do
    import Ecto.Query
    alias Gallformers.Repo
    alias Gallformers.Species.Species

    from(s in Species,
      where: s.id in ^species_ids,
      order_by: s.name,
      select: %{
        id: s.id,
        name: s.name,
        taxoncode: s.taxoncode
      }
    )
    |> Repo.all()
  end

  defp format_with_description(name, description) do
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
          <%= if @genus do %>
            <%!-- Header --%>
            <div class="mb-6">
              <div class="flex items-center justify-between mb-2">
                <h1 class="text-2xl font-bold text-gf-maroon">
                  Genus <em>{format_with_description(@genus.name, @genus.description)}</em>
                </h1>
              </div>

              <%!-- Family link --%>
              <%= if @family do %>
                <div class="text-gray-700">
                  <span class="font-semibold">Family:</span>
                  <.link href={"/family/#{@family.id}"} class="text-gf-maroon hover:underline">
                    <em>{@family.name}</em>
                  </.link>
                  <%= if @family.description do %>
                    <span class="text-gray-600">({@family.description})</span>
                  <% end %>
                </div>
              <% end %>
            </div>

            <%!-- Species list --%>
            <div class="mt-6">
              <%= if length(@species) > 0 do %>
                <h2 class="text-lg font-semibold text-gray-800 mb-3">
                  Species ({length(@species)})
                </h2>
                <div class="bg-white rounded border border-gray-200 overflow-hidden">
                  <table class="gf-table">
                    <thead>
                      <tr>
                        <th>Species Name</th>
                      </tr>
                    </thead>
                    <tbody>
                      <%= for species <- @species do %>
                        <tr>
                          <td>
                            <.link
                              href={"#{if species.taxoncode == "gall", do: "/gall", else: "/host"}/#{species.id}"}
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
                <p class="text-gray-500 italic">No species found for this genus.</p>
              <% end %>
            </div>
          <% else %>
            <div class="bg-red-50 border border-red-200 rounded-lg p-4 text-red-700">
              Genus not found
            </div>
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
