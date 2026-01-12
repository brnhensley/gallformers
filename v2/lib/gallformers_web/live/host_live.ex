defmodule GallformersWeb.HostLive do
  @moduledoc """
  LiveView for the host plant detail page.

  Displays detailed information about a host plant species including
  associated galls, images, range map, and sources.
  """
  use GallformersWeb, :live_view

  alias Gallformers.{Hosts, Sources, Species, Taxonomy}

  @page_size 10

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Integer.parse(id) do
      {host_id, ""} ->
        load_host(socket, host_id)

      _ ->
        {:ok,
         assign(socket,
           page_title: "Host Not Found | Gallformers",
           host: nil,
           error: "Invalid host ID"
         )}
    end
  end

  defp load_host(socket, host_id) do
    case Hosts.get_host(host_id) do
      nil ->
        {:ok,
         assign(socket,
           page_title: "Host Not Found | Gallformers",
           host: nil,
           error: "Host not found"
         )}

      host ->
        galls = Hosts.get_galls_for_host(host_id) |> Enum.sort_by(& &1.name)
        images = Species.get_images_for_species(host_id) |> format_images()
        sources = Sources.get_sources_for_species(host_id)
        aliases = Species.get_aliases_for_species(host_id)
        taxonomy = get_taxonomy_info(host_id)
        range = Hosts.get_places_for_host(host_id) |> MapSet.new()

        default_source = Enum.find(sources, fn s -> s.useasdefault end)
        default_source_id = if default_source, do: default_source.id, else: nil

        {:ok,
         assign(socket,
           page_title: "#{host.name} | Gallformers",
           host: Map.merge(host, %{galls: galls, aliases: aliases}),
           images: images,
           sources: sources,
           taxonomy: taxonomy,
           range: range,
           selected_source_id: default_source_id,
           current_page: 1,
           page_size: @page_size,
           error: nil
         )}
    end
  end

  defp get_taxonomy_info(species_id) do
    Taxonomy.get_taxonomy_for_species(species_id)
  end

  defp format_images(images) do
    base_url = Species.Image.base_url()

    Enum.map(images, fn img ->
      # Replace "original" with size name in the path
      small_path = String.replace(img.path, "original", "small")

      Map.merge(img, %{
        url: "#{base_url}/#{img.path}",
        small_url: "#{base_url}/#{small_path}"
      })
    end)
  end

  @impl true
  def handle_event("prev_page", _params, socket) do
    new_page = max(1, socket.assigns.current_page - 1)
    {:noreply, assign(socket, current_page: new_page)}
  end

  @impl true
  def handle_event("next_page", _params, socket) do
    total_pages = ceil(length(socket.assigns.host.galls) / socket.assigns.page_size)
    new_page = min(total_pages, socket.assigns.current_page + 1)
    {:noreply, assign(socket, current_page: new_page)}
  end

  defp paginated_galls(galls, current_page, page_size) do
    galls
    |> Enum.drop((current_page - 1) * page_size)
    |> Enum.take(page_size)
  end

  defp total_pages(galls, page_size) do
    ceil(length(galls) / page_size)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-7xl">
        <%= if @error do %>
          <div class="bg-red-50 border border-red-200 rounded-lg p-4 text-red-700">{@error}</div>
        <% else %>
          <%= if @host do %>
            <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
              <div class="lg:col-span-2 space-y-2">
                <div class="flex items-start justify-between gap-4">
                  <h2 class="text-2xl font-bold">
                    <.link
                      href={"/id?hostOrTaxon=#{URI.encode(@host.name)}&type=host"}
                      class="hover:underline"
                    >
                      <em>{@host.name}</em>
                    </.link>
                  </h2>
                  <span class={[
                    "inline-flex items-center px-2 py-1 text-xs font-medium rounded-full",
                    if(@host.datacomplete,
                      do: "bg-green-100 text-green-800",
                      else: "bg-yellow-100 text-yellow-800"
                    )
                  ]}>
                    {if @host.datacomplete, do: "Complete", else: "In Progress"}
                  </span>
                </div>

                <%= if @taxonomy do %>
                  <div class="text-sm text-gray-600">
                    {if @taxonomy.family, do: @taxonomy.family, else: ""}
                    {if @taxonomy.family && @taxonomy.genus, do: " > "}
                    {if @taxonomy.genus, do: @taxonomy.genus, else: ""}
                  </div>
                <% end %>

                <%= if @host.aliases && length(@host.aliases) > 0 do %>
                  <div class="mt-2">
                    <strong>Also known as:</strong>
                    <ul class="list-disc list-inside text-sm text-gray-700">
                      <%= for a <- @host.aliases do %>
                        <li><em>{a.name}</em>{if a.type, do: " (#{a.type})"}</li>
                      <% end %>
                    </ul>
                  </div>
                <% end %>

                <div class="pt-2">
                  <%= if length(@host.galls) > 0 do %>
                    <div class="overflow-hidden rounded border border-gray-200">
                      <table class="min-w-full divide-y divide-gray-200">
                        <thead class="bg-cadet-blue">
                          <tr>
                            <th class="px-3 py-2 text-left text-sm font-medium text-gray-900">
                              Gall
                            </th>
                          </tr>
                        </thead>
                        <tbody class="bg-white divide-y divide-gray-200">
                          <%= for {gall, i} <- Enum.with_index(paginated_galls(@host.galls, @current_page, @page_size)) do %>
                            <tr class={"hover:bg-gray-50 #{if rem(i, 2) == 1, do: "bg-gray-50"}"}>
                              <td class="px-3 py-2 text-sm">
                                <.link href={"/gall/#{gall.id}"} class="hover:underline">
                                  <em>{gall.name}</em>
                                </.link>
                              </td>
                            </tr>
                          <% end %>
                        </tbody>
                      </table>
                      <%= if total_pages(@host.galls, @page_size) > 1 do %>
                        <div class="flex items-center justify-between px-3 py-1 bg-white border-t border-gray-200">
                          <div class="text-sm">
                            {(@current_page - 1) * @page_size + 1}-{min(
                              @current_page * @page_size,
                              length(@host.galls)
                            )} of {length(@host.galls)}
                          </div>
                          <div class="flex items-center gap-2">
                            <button
                              class="px-2 py-0.5 text-sm border rounded hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed"
                              disabled={@current_page == 1}
                              phx-click="prev_page"
                            >
                              Previous
                            </button>
                            <span class="text-sm">
                              Page {@current_page} of {total_pages(@host.galls, @page_size)}
                            </span>
                            <button
                              class="px-2 py-0.5 text-sm border rounded hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed"
                              disabled={@current_page == total_pages(@host.galls, @page_size)}
                              phx-click="next_page"
                            >
                              Next
                            </button>
                          </div>
                        </div>
                      <% end %>
                    </div>
                  <% else %>
                    <p class="italic">No galls recorded for this host.</p>
                  <% end %>
                </div>
              </div>

              <div class="lg:col-span-1">
                <%= if length(@images) > 0 do %>
                  <div class="bg-white rounded border border-gray-200 overflow-hidden">
                    <img src={hd(@images).url} alt="Host image" class="w-full h-48 object-cover" />
                  </div>
                  <%= if hd(@images).creator do %>
                    <p class="text-xs text-gray-500 mt-1">
                      Photo: {hd(@images).creator}{if hd(@images).license,
                        do: " (#{hd(@images).license})"}
                    </p>
                  <% end %>
                <% else %>
                  <div class="bg-gray-100 rounded p-6 text-center text-gray-500">
                    No images available
                  </div>
                <% end %>

                <%= if MapSet.size(@range) > 0 do %>
                  <div class="mt-4">
                    <strong>Possible Range:</strong> {MapSet.size(@range)} regions
                  </div>
                <% end %>
              </div>
            </div>

            <hr class="border-gray-200 my-4" />

            <%= if length(@sources) > 0 do %>
              <h3 class="font-semibold mb-2">Sources ({length(@sources)})</h3>
              <div class="space-y-2">
                <%= for source <- @sources do %>
                  <div class={"p-3 rounded border #{if source.id == @selected_source_id, do: "border-gf-maroon bg-canary", else: "border-gray-200 bg-white"}"}>
                    <.link
                      href={"/source/#{source.id}"}
                      class="font-medium text-gf-maroon hover:underline"
                    >
                      {source.title}
                    </.link>
                    {if source.author, do: " - #{source.author}"}
                    {if source.pubyear, do: " (#{source.pubyear})"}
                  </div>
                <% end %>
              </div>
            <% else %>
              <p class="italic">No sources available for this species.</p>
            <% end %>

            <hr class="border-gray-200 my-4" />
            <div class="mb-2"><strong>See Also:</strong></div>
            <div class="flex flex-wrap gap-4 text-sm">
              <.link
                href={"https://www.inaturalist.org/taxa/search?q=#{URI.encode(@host.name)}"}
                target="_blank"
                rel="noreferrer"
                class="text-gf-maroon hover:underline"
              >
                iNaturalist
              </.link>
              <.link
                href={"https://scholar.google.com/scholar?q=#{URI.encode(@host.name)}"}
                target="_blank"
                rel="noreferrer"
                class="text-gf-maroon hover:underline"
              >
                Google Scholar
              </.link>
            </div>
          <% else %>
            <div class="bg-red-50 border border-red-200 rounded-lg p-4 text-red-700">
              Host not found
            </div>
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
