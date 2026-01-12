defmodule GallformersWeb.FamilyLive do
  @moduledoc """
  LiveView for the taxonomic family listing page.

  Displays a family with its genera and species in an expandable tree view.
  """
  use GallformersWeb, :live_view

  alias Gallformers.Taxonomy

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Integer.parse(id) do
      {family_id, ""} ->
        load_family(socket, family_id)

      _ ->
        {:ok, assign(socket, page_title: "Family Not Found | Gallformers", family: nil, error: "Invalid family ID")}
    end
  end

  defp load_family(socket, family_id) do
    case Taxonomy.get_taxonomy(family_id) do
      nil ->
        {:ok, assign(socket, page_title: "Family Not Found | Gallformers", family: nil, error: "Family not found")}

      family ->
        if family.type != "family" do
          {:ok, assign(socket, page_title: "Family Not Found | Gallformers", family: nil, error: "Not a family")}
        else
          # Get genera under this family
          genera = Taxonomy.get_children(family_id)

          # Build tree data
          tree_data = build_tree_data(genera)

          {:ok,
           assign(socket,
             page_title: "#{family.name} | Gallformers",
             family: family,
             tree_data: tree_data,
             expanded_keys: MapSet.new(),
             error: nil
           )}
        end
    end
  end

  defp build_tree_data(genera) do
    Enum.map(genera, fn genus ->
      # Get species for this genus
      species_ids = Taxonomy.get_species_ids_for_genus(genus.id)

      species =
        if length(species_ids) > 0 do
          get_species_info(species_ids)
        else
          []
        end

      %{
        id: genus.id,
        name: genus.name,
        description: genus.description,
        type: :genus,
        children: species
      }
    end)
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
    |> Enum.map(fn s ->
      url = if s.taxoncode == "gall", do: "/gall/#{s.id}", else: "/host/#{s.id}"
      Map.put(s, :url, url)
    end)
  end

  @impl true
  def handle_event("toggle_genus", %{"id" => id}, socket) do
    genus_id = String.to_integer(id)
    expanded_keys = socket.assigns.expanded_keys

    new_expanded =
      if MapSet.member?(expanded_keys, genus_id) do
        MapSet.delete(expanded_keys, genus_id)
      else
        MapSet.put(expanded_keys, genus_id)
      end

    {:noreply, assign(socket, expanded_keys: new_expanded)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-7xl">
        <%= if @error do %>
          <div class="bg-red-50 border border-red-200 rounded-lg p-4 text-red-700">{@error}</div>
        <% else %>
          <%= if @family do %>
            <%!-- Header --%>
            <div class="bg-white rounded border border-gray-200 shadow-sm">
              <div class="px-4 py-3 border-b border-gray-200">
                <div class="flex items-center justify-between">
                  <h1 class="text-2xl font-bold text-gf-maroon">
                    {@family.name}
                    <%= if @family.description do %>
                      <span class="text-lg font-normal text-gray-600">
                        - {@family.description}
                      </span>
                    <% end %>
                  </h1>
                </div>
              </div>
              <div class="p-4">
                <%= if length(@tree_data) > 0 do %>
                  <div class="space-y-2">
                    <%= for genus <- @tree_data do %>
                      <div class="border rounded">
                        <button
                          phx-click="toggle_genus"
                          phx-value-id={genus.id}
                          class="w-full px-3 py-2 text-left bg-gray-50 hover:bg-gray-100 flex justify-between items-center"
                        >
                          <span>
                            <em class="font-medium">{genus.name}</em>
                            <%= if genus.description do %>
                              <span class="text-gray-600"> - {genus.description}</span>
                            <% end %>
                            <span class="text-sm text-gray-500 ml-2">
                              ({length(genus.children)} species)
                            </span>
                          </span>
                          <svg
                            class={"w-5 h-5 text-gray-500 transition-transform #{if MapSet.member?(@expanded_keys, genus.id), do: "rotate-180"}"}
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
                        <%= if MapSet.member?(@expanded_keys, genus.id) do %>
                          <div class="border-t bg-white">
                            <ul class="divide-y">
                              <%= for species <- genus.children do %>
                                <li class="px-6 py-2 hover:bg-gray-50">
                                  <.link href={species.url} class="text-gf-maroon hover:underline">
                                    <em>{species.name}</em>
                                  </.link>
                                </li>
                              <% end %>
                            </ul>
                          </div>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                <% else %>
                  <p class="text-gray-500 italic">No genera or species found for this family.</p>
                <% end %>
              </div>
            </div>
          <% else %>
            <div class="bg-red-50 border border-red-200 rounded-lg p-4 text-red-700">Family not found</div>
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

end
