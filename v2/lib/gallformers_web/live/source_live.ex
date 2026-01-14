defmodule GallformersWeb.SourceLive do
  @moduledoc """
  LiveView for the source/reference detail page.

  Displays detailed information about a scientific source including
  metadata and connected species.
  """
  use GallformersWeb, :live_view

  alias Gallformers.Sources

  @page_size 20

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Integer.parse(id) do
      {source_id, ""} ->
        load_source(socket, source_id)

      _ ->
        {:ok,
         assign(socket,
           page_title: "Source Not Found",
           page_description: "The requested source was not found on Gallformers.",
           page_url: nil,
           page_image: nil,
           page_json_ld: nil,
           page_noindex: true,
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
           page_title: "Source Not Found",
           page_description: "The requested source was not found on Gallformers.",
           page_url: nil,
           page_image: nil,
           page_json_ld: nil,
           page_noindex: true,
           source: nil,
           error: "Source not found"
         )}

      source ->
        # Get connected species
        species = Sources.get_species_for_source(source_id) |> Enum.sort_by(& &1.name)
        author_text = if source.author, do: " by #{source.author}", else: ""

        {:ok,
         assign(socket,
           page_title: source.title,
           page_description:
             "#{source.title}#{author_text} - A source referenced on Gallformers.",
           page_url: "/source/#{source_id}",
           page_image: nil,
           page_json_ld: nil,
           page_noindex: false,
           source: source,
           species: species,
           current_page: 1,
           page_size: @page_size,
           error: nil
         )}
    end
  end

  @impl true
  def handle_event("page", %{"page" => page}, socket) do
    page = max(1, min(page, total_pages(socket.assigns.species, socket.assigns.page_size)))
    {:noreply, assign(socket, current_page: page)}
  end

  defp paginated_species(species, current_page, page_size) do
    species
    |> Enum.drop((current_page - 1) * page_size)
    |> Enum.take(page_size)
  end

  defp total_pages(species, page_size) do
    max(1, ceil(length(species) / page_size))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div>
        <%= if @error do %>
          <div class="bg-red-50 border border-red-200 rounded-lg p-4 text-red-700">{@error}</div>
        <% else %>
          <%= if @source do %>
            <%!-- Header --%>
            <div class="mb-6">
              <div class="flex items-start justify-between gap-4 mb-2">
                <div class="flex items-center gap-2">
                  <h1 class="text-2xl font-bold text-gf-maroon">{@source.title}</h1>
                  <.link
                    :if={@current_user}
                    href={~p"/admin/sources/#{@source.id}"}
                    class="text-gray-400 hover:text-gf-maroon"
                    title="Edit in admin"
                  >
                    <.icon name="ph-pencil-simple" class="h-5 w-5" />
                  </.link>
                </div>
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
                <div class="bg-white rounded border border-gray-200 overflow-hidden">
                  <table class="gf-table gf-table-compact">
                    <thead>
                      <tr>
                        <th>Species Name</th>
                        <th>Type</th>
                      </tr>
                    </thead>
                    <tbody>
                      <%= for species <- paginated_species(@species, @current_page, @page_size) do %>
                        <tr>
                          <td>
                            <.link
                              href={"#{if species.taxoncode == "gall", do: "/gall", else: "/host"}/#{species.id}"}
                              class="text-gf-maroon hover:underline"
                            >
                              <em>{species.name}</em>
                            </.link>
                          </td>
                          <td class="text-gray-600">
                            {if species.taxoncode == "gall", do: "Gall", else: "Host"}
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
                <%= if total_pages(@species, @page_size) > 1 do %>
                  <.pagination
                    page={@current_page}
                    total_pages={total_pages(@species, @page_size)}
                    total_items={length(@species)}
                    page_size={@page_size}
                    on_page_change={fn page -> JS.push("page", value: %{page: page}) end}
                    class="mt-4"
                  />
                <% end %>
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
