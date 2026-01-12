defmodule GallformersWeb.SourceLive do
  @moduledoc """
  LiveView for the source/reference detail page.

  Displays detailed information about a scientific source including
  metadata and connected species.
  """
  use GallformersWeb, :live_view

  alias Gallformers.Sources

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Integer.parse(id) do
      {source_id, ""} ->
        load_source(socket, source_id)

      _ ->
        {:ok,
         assign(socket,
           page_title: "Source Not Found | Gallformers",
           source: nil,
           error: "Invalid source ID"
         )}
    end
  end

  defp load_source(socket, source_id) do
    case Sources.get_source(source_id) do
      nil ->
        {:ok,
         assign(socket,
           page_title: "Source Not Found | Gallformers",
           source: nil,
           error: "Source not found"
         )}

      source ->
        # Get connected species
        species = Sources.get_species_for_source(source_id) |> Enum.sort_by(& &1.name)

        {:ok,
         assign(socket,
           page_title: "#{source.title} | Gallformers",
           source: source,
           species: species,
           error: nil
         )}
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
          <%= if @source do %>
            <%!-- Header --%>
            <div class="mb-6">
              <div class="flex items-start justify-between gap-4 mb-2">
                <h1 class="text-2xl font-bold text-gf-maroon">{@source.title}</h1>
                <div class="flex items-center gap-2">
                  <%= if @source.datacomplete do %>
                    <span
                      class="inline-flex items-center px-2 py-1 text-xs font-medium rounded-full bg-green-100 text-green-800"
                      title="This source has been comprehensively reviewed and all relevant information entered."
                    >
                      Complete
                    </span>
                  <% else %>
                    <span
                      class="inline-flex items-center px-2 py-1 text-xs font-medium rounded-full bg-yellow-100 text-yellow-800"
                      title="We are still working on this source so information from the source is potentially still missing."
                    >
                      In Progress
                    </span>
                  <% end %>
                </div>
              </div>

              <%= if @source.link do %>
                <.link
                  href={@source.link}
                  target="_blank"
                  rel="noopener noreferrer"
                  class="text-gf-maroon hover:underline break-all"
                >
                  {@source.link}
                </.link>
              <% end %>
            </div>

            <%!-- Source Info Grid --%>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
              <div>
                <span class="font-semibold text-gray-700">Authors:</span>
                <span class="text-gray-900">{@source.author || "Not specified"}</span>
              </div>
              <div>
                <span class="font-semibold text-gray-700">License:</span>
                <%= if @source.licenselink do %>
                  <.link
                    href={@source.licenselink}
                    target="_blank"
                    rel="noopener noreferrer"
                    class="text-gf-maroon hover:underline"
                  >
                    {@source.license || "View"}
                  </.link>
                <% else %>
                  <span class="text-gray-900">{@source.license || "Not specified"}</span>
                <% end %>
              </div>
              <div>
                <span class="font-semibold text-gray-700">Publication Year:</span>
                <span class="text-gray-900">{@source.pubyear || "Not specified"}</span>
              </div>
            </div>

            <%!-- Citation --%>
            <%= if @source.citation do %>
              <div class="mb-6">
                <span class="font-semibold text-gray-700">Citation (MLA Form):</span>
                <p class="text-gray-900 italic mt-1">{@source.citation}</p>
              </div>
            <% end %>

            <%!-- Connected Species --%>
            <div class="mt-8">
              <h2 class="text-lg font-semibold text-gray-800 mb-3">
                Connected Species ({length(@species)})
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
                <p class="text-gray-500 italic">No species connected to this source.</p>
              <% end %>
            </div>
          <% else %>
            <div class="bg-red-50 border border-red-200 rounded-lg p-4 text-red-700">
              Source not found
            </div>
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
