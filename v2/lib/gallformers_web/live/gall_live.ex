defmodule GallformersWeb.GallLive do
  @moduledoc """
  LiveView for the gall/species detail page.

  Displays detailed information about a gall species including morphology,
  hosts, images, range map, and sources.
  """
  use GallformersWeb, :live_view

  alias Gallformers.{Hosts, Sources, Species, Taxonomy}

  @detachable_values %{
    0 => "",
    1 => "Integral",
    2 => "Detachable",
    3 => "Both"
  }

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Integer.parse(id) do
      {gall_id, ""} ->
        load_gall(socket, gall_id)

      _ ->
        {:ok, assign(socket, page_title: "Gall Not Found | Gallformers", gall: nil, error: "Invalid gall ID")}
    end
  end

  defp load_gall(socket, gall_id) do
    case Species.get_gall_by_id(gall_id) do
      nil ->
        {:ok, assign(socket, page_title: "Gall Not Found | Gallformers", gall: nil, error: "Gall not found")}

      gall ->
        hosts = Hosts.get_hosts_for_gall(gall_id)
        images = Species.get_images_for_species(gall_id) |> format_images()
        sources = Sources.get_sources_for_species(gall_id)
        aliases = Species.get_aliases_for_species(gall_id)
        taxonomy = get_taxonomy_info(gall_id)
        range = Hosts.get_places_for_gall(gall_id) |> MapSet.new()
        gall_filters = get_gall_filter_fields(gall.gall_id)

        default_source = Enum.find(sources, fn s -> s.useasdefault end)
        default_source_id = if default_source, do: default_source.id, else: nil

        {:ok,
         assign(socket,
           page_title: "#{gall.name} | Gallformers",
           gall: Map.merge(gall, %{hosts: hosts, aliases: aliases}),
           gall_filters: gall_filters,
           images: images,
           sources: sources,
           taxonomy: taxonomy,
           range: range,
           selected_source_id: default_source_id,
           error: nil
         )}
    end
  end

  defp get_taxonomy_info(species_id) do
    Taxonomy.get_taxonomy_for_species(species_id)
  end

  defp format_images(images) do
    base_url = Gallformers.Species.Image.base_url()

    Enum.map(images, fn img ->
      Map.merge(img, %{
        url: "#{base_url}/#{img.path}",
        small_url: "#{base_url}/small/#{img.path}"
      })
    end)
  end

  defp get_gall_filter_fields(gall_id) do
    %{
      colors: get_filter_values(gall_id, "gallcolor", "color_id", Gallformers.FilterFields.Color, :color),
      shapes: get_filter_values(gall_id, "gallshape", "shape_id", Gallformers.FilterFields.Shape, :shape),
      textures: get_filter_values(gall_id, "galltexture", "texture_id", Gallformers.FilterFields.Texture, :texture),
      alignments: get_filter_values(gall_id, "gallalignment", "alignment_id", Gallformers.FilterFields.Alignment, :alignment),
      walls: get_filter_values(gall_id, "gallwalls", "walls_id", Gallformers.FilterFields.Walls, :walls),
      locations: get_filter_values(gall_id, "galllocation", "location_id", Gallformers.FilterFields.Location, :location),
      forms: get_filter_values(gall_id, "gallform", "form_id", Gallformers.FilterFields.Form, :form),
      cells: get_filter_values(gall_id, "gallcells", "cells_id", Gallformers.FilterFields.Cells, :cells),
      seasons: get_filter_values(gall_id, "gallseason", "season_id", Gallformers.FilterFields.Season, :season)
    }
  end

  defp get_filter_values(gall_id, join_table, fk_column, schema, field) do
    import Ecto.Query
    alias Gallformers.Repo

    fk_col = String.to_atom(fk_column)

    from(j in join_table,
      join: s in ^schema,
      on: field(j, ^fk_col) == s.id,
      where: j.gall_id == ^gall_id,
      select: field(s, ^field)
    )
    |> Repo.all()
  end

  defp get_detachable_display(value), do: Map.get(@detachable_values, value, "")
  defp format_fields(fields), do: Enum.join(fields, ", ")

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-7xl">
        <%= if @error do %>
          <div class="bg-red-50 border border-red-200 rounded-lg p-4 text-red-700">{@error}</div>
        <% else %>
          <%= if @gall do %>
            <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
              <div class="lg:col-span-2 space-y-2">
                <div class="flex items-start justify-between gap-4">
                  <h2 class="text-2xl font-bold"><em>{@gall.name}</em></h2>
                  <span class={[
                    "inline-flex items-center px-2 py-1 text-xs font-medium rounded-full",
                    if(@gall.datacomplete, do: "bg-green-100 text-green-800", else: "bg-yellow-100 text-yellow-800")
                  ]}>
                    {if @gall.datacomplete, do: "Complete", else: "In Progress"}
                  </span>
                </div>

                <%= if @gall.undescribed do %>
                  <div class="text-red-600">The inducer of this gall is unknown or undescribed.</div>
                <% end %>

                <%= if @taxonomy do %>
                  <div class="text-sm text-gray-600">
                    {if @taxonomy.family, do: @taxonomy.family, else: ""}
                    {if @taxonomy.family && @taxonomy.genus, do: " > "}
                    {if @taxonomy.genus, do: @taxonomy.genus, else: ""}
                  </div>
                <% end %>

                <%= if @gall.hosts && length(@gall.hosts) > 0 do %>
                  <div>
                    <strong>Hosts:</strong>
                    <em>
                      <%= for {host, i} <- Enum.with_index(@gall.hosts) do %>
                        <.link href={"/host/#{host.host_species_id}"} class="hover:underline text-gf-maroon">
                          {host.host_name}
                        </.link>{if i < length(@gall.hosts) - 1, do: " / "}
                      <% end %>
                    </em>
                  </div>
                <% end %>

                <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-x-4">
                  <div class="space-y-1">
                    <div><strong>Detachable:</strong> {get_detachable_display(@gall.detachable)}</div>
                    <div><strong>Color:</strong> {format_fields(@gall_filters.colors)}</div>
                    <div><strong>Texture:</strong> {format_fields(@gall_filters.textures)}</div>
                    <div><strong>Abundance:</strong> {@gall.abundance_name || ""}</div>
                    <div><strong>Shape:</strong> {format_fields(@gall_filters.shapes)}</div>
                    <div><strong>Season:</strong> {format_fields(@gall_filters.seasons)}</div>
                  </div>
                  <div class="space-y-1">
                    <div><strong>Alignment:</strong> {format_fields(@gall_filters.alignments)}</div>
                    <div><strong>Walls:</strong> {format_fields(@gall_filters.walls)}</div>
                    <div><strong>Location:</strong> {format_fields(@gall_filters.locations)}</div>
                    <div><strong>Form:</strong> {format_fields(@gall_filters.forms)}</div>
                    <div><strong>Cells:</strong> {format_fields(@gall_filters.cells)}</div>
                  </div>
                  <div>
                    <div><strong>Possible Range:</strong> {MapSet.size(@range)} regions</div>
                  </div>
                </div>

                <%= if @gall.aliases && length(@gall.aliases) > 0 do %>
                  <div class="mt-2">
                    <strong>Also known as:</strong>
                    <ul class="list-disc list-inside text-sm text-gray-700">
                      <%= for a <- @gall.aliases do %>
                        <li><em>{a.name}</em>{if a.type, do: " (#{a.type})"}</li>
                      <% end %>
                    </ul>
                  </div>
                <% end %>
              </div>

              <div class="lg:col-span-1">
                <%= if length(@images) > 0 do %>
                  <div class="bg-white rounded border border-gray-200 overflow-hidden">
                    <img src={hd(@images).url} alt="Gall image" class="w-full h-48 object-cover" />
                  </div>
                  <%= if hd(@images).creator do %>
                    <p class="text-xs text-gray-500 mt-1">
                      Photo: {hd(@images).creator}{if hd(@images).license, do: " (#{hd(@images).license})"}
                    </p>
                  <% end %>
                <% else %>
                  <div class="bg-gray-100 rounded p-6 text-center text-gray-500">No images available</div>
                <% end %>
              </div>
            </div>

            <hr class="border-gray-200 my-4" />

            <%= if length(@sources) > 0 do %>
              <h3 class="font-semibold mb-2">Sources ({length(@sources)})</h3>
              <div class="space-y-2">
                <%= for source <- @sources do %>
                  <div class={"p-3 rounded border #{if source.id == @selected_source_id, do: "border-gf-maroon bg-canary", else: "border-gray-200 bg-white"}"}>
                    <.link href={"/source/#{source.id}"} class="font-medium text-gf-maroon hover:underline">
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
              <.link href={"https://www.inaturalist.org/taxa/search?q=#{URI.encode(@gall.name)}"} target="_blank" rel="noreferrer" class="text-gf-maroon hover:underline">iNaturalist</.link>
              <.link href={"https://bugguide.net/index.php?q=search&keys=#{URI.encode(@gall.name)}"} target="_blank" rel="noreferrer" class="text-gf-maroon hover:underline">BugGuide</.link>
              <.link href={"https://scholar.google.com/scholar?q=#{URI.encode(@gall.name)}"} target="_blank" rel="noreferrer" class="text-gf-maroon hover:underline">Google Scholar</.link>
            </div>
          <% else %>
            <div class="bg-red-50 border border-red-200 rounded-lg p-4 text-red-700">Gall not found</div>
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
