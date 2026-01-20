defmodule GallformersWeb.PlaceLive do
  @moduledoc """
  LiveView for the geographic place detail page.

  Displays a place (state/province) with its list of host plants.
  """
  use GallformersWeb, :live_view

  import Ecto.Query

  alias Gallformers.Repo
  alias Gallformers.Species.Species

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Integer.parse(id) do
      {place_id, ""} ->
        load_place(socket, place_id)

      _ ->
        {:ok,
         assign(socket,
           page_title: "Place Not Found",
           page_description: "The requested geographic location was not found on Gallformers.",
           page_url: nil,
           page_image: nil,
           page_json_ld: nil,
           page_noindex: true,
           place: nil,
           error: "Invalid place ID"
         )}
    end
  end

  defp load_place(socket, place_id) do
    case get_place(place_id) do
      nil ->
        {:ok,
         assign(socket,
           page_title: "Place Not Found",
           page_description: "The requested geographic location was not found on Gallformers.",
           page_url: nil,
           page_image: nil,
           page_json_ld: nil,
           page_noindex: true,
           place: nil,
           error: "Place not found"
         )}

      place ->
        # Get parent place
        parent = if place.parent_id, do: get_place(place.parent_id), else: nil

        # Get hosts for this place
        hosts = get_hosts_for_place(place_id)

        {:ok,
         assign(socket,
           page_title: place.name,
           page_description:
             "#{place.name} - Host plants found in this geographic location on Gallformers.",
           page_url: "/place/#{place_id}",
           page_image: nil,
           page_json_ld: nil,
           page_noindex: false,
           place: place,
           parent: parent,
           hosts: hosts,
           error: nil
         )}
    end
  end

  defp get_place(place_id) do
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
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="mx-auto max-w-7xl">
        <%= if @error do %>
          <div class="bg-red-50 border border-red-200 rounded-lg p-4 text-red-700">{@error}</div>
        <% else %>
          <%= if @place do %>
            <%!-- Header --%>
            <div class="mb-6">
              <div class="flex items-center justify-between mb-2">
                <div class="flex items-center gap-2">
                  <h1 class="text-2xl font-bold text-gf-maroon">
                    {@place.name} - {@place.code}
                  </h1>
                  <.link
                    :if={@current_user}
                    href={~p"/admin/places/#{@place.id}"}
                    class="text-gray-400 hover:text-gf-maroon"
                    title="Edit in admin"
                  >
                    <.icon name="ph-pencil-simple" class="h-5 w-5" />
                  </.link>
                </div>
              </div>

              <%!-- Parent info --%>
              <p :if={@parent} class="text-gray-600">
                {format_parent_info(@place, @parent)}
              </p>
            </div>

            <%!-- Hosts list --%>
            <div class="mt-6">
              <h2 class="text-lg font-semibold text-gray-800 mb-3">
                Host Plants ({length(@hosts)})
              </h2>
              <%= if length(@hosts) > 0 do %>
                <div class="bg-white rounded border border-gray-200 overflow-hidden">
                  <table class="gf-table">
                    <thead>
                      <tr>
                        <th>Species Name</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr :for={host <- @hosts}>
                        <td>
                          <.link
                            href={"/host/#{host.id}"}
                            class="hover:underline"
                          >
                            <em>{host.name}</em>
                          </.link>
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              <% else %>
                <p class="text-gray-500 italic">No host plants found for this location.</p>
              <% end %>
            </div>
          <% else %>
            <div class="bg-red-50 border border-red-200 rounded-lg p-4 text-red-700">
              Place not found
            </div>
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
