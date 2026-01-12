defmodule GallformersWeb.PlaceLive do
  @moduledoc """
  LiveView for the geographic place detail page.

  Displays a place (state/province) with its list of host plants.
  """
  use GallformersWeb, :live_view

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Integer.parse(id) do
      {place_id, ""} ->
        load_place(socket, place_id)

      _ ->
        {:ok, assign(socket, page_title: "Place Not Found | Gallformers", place: nil, error: "Invalid place ID")}
    end
  end

  defp load_place(socket, place_id) do
    case get_place(place_id) do
      nil ->
        {:ok, assign(socket, page_title: "Place Not Found | Gallformers", place: nil, error: "Place not found")}

      place ->
        # Get parent place
        parent = if place.parent_id, do: get_place(place.parent_id), else: nil

        # Get hosts for this place
        hosts = get_hosts_for_place(place_id)

        {:ok,
         assign(socket,
           page_title: "#{place.name} | Gallformers",
           place: place,
           parent: parent,
           hosts: hosts,
           error: nil
         )}
    end
  end

  defp get_place(place_id) do
    import Ecto.Query
    alias Gallformers.Repo

    from(p in "place",
      where: p.id == ^place_id,
      select: %{
        id: p.id,
        name: p.name,
        code: p.code,
        type: p.type,
        parent_id: p.parent_id
      }
    )
    |> Repo.one()
  end

  defp get_hosts_for_place(place_id) do
    import Ecto.Query
    alias Gallformers.Repo
    alias Gallformers.Species.Species

    from(s in Species,
      join: sp in "speciesplace",
      on: sp.species_id == s.id,
      where: sp.place_id == ^place_id and s.taxoncode == "plant",
      order_by: s.name,
      select: %{
        id: s.id,
        name: s.name
      }
    )
    |> Repo.all()
  end

  defp format_parent_info(place, parent) do
    if parent do
      article = if parent.name == "United States", do: "the ", else: ""
      "a #{place.type} of #{article}#{parent.name}"
    else
      ""
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-7xl">
        <%= if @error do %>
          <div class="bg-red-50 border border-red-200 rounded-lg p-4 text-red-700">{@error}</div>
        <% else %>
          <%= if @place do %>
            <%!-- Header --%>
            <div class="mb-6">
              <div class="flex items-center justify-between mb-2">
                <h1 class="text-2xl font-bold text-gf-maroon">
                  {@place.name} - {@place.code}
                </h1>
              </div>

              <%!-- Parent info --%>
              <%= if @parent do %>
                <p class="text-gray-600">
                  {format_parent_info(@place, @parent)}
                </p>
              <% end %>
            </div>

            <%!-- Hosts list --%>
            <div class="mt-6">
              <h2 class="text-lg font-semibold text-gray-800 mb-3">
                Host Plants ({length(@hosts)})
              </h2>
              <%= if length(@hosts) > 0 do %>
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
                      <%= for host <- @hosts do %>
                        <tr class="hover:bg-gray-50">
                          <td class="px-6 py-4 whitespace-nowrap text-sm">
                            <.link
                              href={"/host/#{host.id}"}
                              class="text-gf-maroon hover:underline"
                            >
                              <em>{host.name}</em>
                            </.link>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              <% else %>
                <p class="text-gray-500 italic">No host plants found for this location.</p>
              <% end %>
            </div>
          <% else %>
            <div class="bg-red-50 border border-red-200 rounded-lg p-4 text-red-700">Place not found</div>
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

end
