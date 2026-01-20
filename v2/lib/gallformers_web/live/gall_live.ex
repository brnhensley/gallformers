defmodule GallformersWeb.GallLive do
  @moduledoc """
  LiveView for the gall/species detail page.

  Displays detailed information about a gall species including morphology,
  hosts, images, range map, and sources.
  """
  use GallformersWeb, :live_view

  alias Gallformers.{Hosts, Markdown, Sources, Species, Taxonomy}
  alias GallformersWeb.SEO

  @aliases_page_size 10

  @detachable_values %{
    0 => "",
    1 => "Integral",
    2 => "Detachable",
    3 => "Both"
  }

  # Gallformers Notes source ID (same as V1)
  @gallformers_notes_source_id 58

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Integer.parse(id) do
      {gall_id, ""} ->
        load_gall(socket, gall_id)

      _ ->
        {:ok,
         assign(socket,
           page_title: "Gall Not Found",
           page_description: "The requested gall was not found on Gallformers.",
           page_url: nil,
           page_image: nil,
           page_json_ld: nil,
           page_noindex: true,
           gall: nil,
           error: "Invalid gall ID"
         )}
    end
  end

  defp load_gall(socket, gall_id) do
    case Species.get_gall_by_id(gall_id) do
      nil ->
        {:ok,
         assign(socket,
           page_title: "Gall Not Found",
           page_description: "The requested gall was not found on Gallformers.",
           page_url: nil,
           page_image: nil,
           page_json_ld: nil,
           page_noindex: true,
           gall: nil,
           error: "Gall not found"
         )}

      gall ->
        hosts = Hosts.get_hosts_for_gall(gall_id)
        images = Species.get_images_for_species(gall_id) |> format_images()
        sources = Sources.get_sources_for_species(gall_id)
        aliases = Species.get_aliases_for_species(gall_id)
        taxonomy = get_taxonomy_info(gall_id)
        range = Hosts.get_places_for_gall(gall_id) |> MapSet.new()
        excluded_range = Hosts.get_excluded_places_for_gall(gall_id) |> MapSet.new()
        gall_filters = get_gall_filter_fields(gall.gall_id)

        # Check if Gallformers notes exist for this species
        gallformers_notes = Enum.find(sources, fn s -> s.id == @gallformers_notes_source_id end)
        has_gallformers_notes = gallformers_notes != nil

        # Build SEO data
        page_url = "/gall/#{gall_id}"

        page_description =
          if gall.undescribed do
            "#{gall.name} - A gall species on Gallformers. The inducer of this gall is unknown or undescribed."
          else
            "#{gall.name} - A gall species documented on Gallformers."
          end

        page_image =
          case images do
            [first | _] -> first.url
            [] -> nil
          end

        # Build JSON-LD structured data
        json_ld = build_species_json_ld(gall, page_url, page_description, page_image)

        {:ok,
         assign(socket,
           page_title: gall.name,
           page_description: page_description,
           page_url: page_url,
           page_image: page_image,
           page_json_ld: json_ld,
           page_noindex: false,
           gall: Map.merge(gall, %{hosts: hosts, aliases: aliases}),
           gall_filters: gall_filters,
           images: images,
           sources: sources,
           taxonomy: taxonomy,
           range: range,
           excluded_range: excluded_range,
           has_gallformers_notes: has_gallformers_notes,
           notes_alert_dismissed: false,
           aliases_page: 1,
           aliases_page_size: @aliases_page_size,
           error: nil
         )}
    end
  end

  defp build_species_json_ld(gall, url, description, image) do
    json_ld = %{
      "@context" => "https://schema.org",
      "@type" => "Thing",
      "name" => gall.name,
      "description" => description,
      "url" => SEO.base_url() <> url,
      "identifier" => gall.name
    }

    json_ld = if image, do: Map.put(json_ld, "image", image), else: json_ld

    Phoenix.HTML.raw(~s(<script type="application/ld+json">#{Jason.encode!(json_ld)}</script>))
  end

  defp get_taxonomy_info(species_id) do
    Taxonomy.get_taxonomy_for_species(species_id)
  end

  defp format_images(images) do
    base_url = Species.Image.base_url()

    Enum.map(images, fn img ->
      # Replace "original" with size name in the path
      small_path = String.replace(img.path, "original", "small")
      full_url = "#{base_url}/#{img.path}"

      Map.merge(img, %{
        url: full_url,
        src: full_url,
        small_url: "#{base_url}/#{small_path}",
        alt: "Gall image"
      })
    end)
  end

  defp get_gall_filter_fields(gall_id) do
    %{
      colors:
        get_filter_values(
          gall_id,
          "gallcolor",
          :color_id,
          Gallformers.FilterFields.Color,
          :color
        ),
      shapes:
        get_filter_values(
          gall_id,
          "gallshape",
          :shape_id,
          Gallformers.FilterFields.Shape,
          :shape
        ),
      textures:
        get_filter_values(
          gall_id,
          "galltexture",
          :texture_id,
          Gallformers.FilterFields.Texture,
          :texture
        ),
      alignments:
        get_filter_values(
          gall_id,
          "gallalignment",
          :alignment_id,
          Gallformers.FilterFields.Alignment,
          :alignment
        ),
      walls:
        get_filter_values(
          gall_id,
          "gallwalls",
          :walls_id,
          Gallformers.FilterFields.Walls,
          :walls
        ),
      locations:
        get_filter_values(
          gall_id,
          "galllocation",
          :location_id,
          Gallformers.FilterFields.Location,
          :location
        ),
      forms:
        get_filter_values(gall_id, "gallform", :form_id, Gallformers.FilterFields.Form, :form),
      cells:
        get_filter_values(
          gall_id,
          "gallcells",
          :cells_id,
          Gallformers.FilterFields.Cells,
          :cells
        ),
      seasons:
        get_filter_values(
          gall_id,
          "gallseason",
          :season_id,
          Gallformers.FilterFields.Season,
          :season
        )
    }
  end

  defp get_filter_values(gall_id, join_table, fk_col, schema, field) when is_atom(fk_col) do
    import Ecto.Query
    alias Gallformers.Repo

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

  # Extract the gallformers code from the species name by removing the genus and any trailing parenthetical
  defp get_gallformers_code(species_name, genus_name) when is_binary(genus_name) do
    species_name
    |> String.replace(genus_name, "")
    |> String.trim()
    |> String.replace(~r/ \([^)]+\)$/, "")
  end

  defp get_gallformers_code(species_name, _), do: species_name

  @impl true
  def handle_event("dismiss_notes_alert", _params, socket) do
    {:noreply, assign(socket, notes_alert_dismissed: true)}
  end

  @impl true
  def handle_event("clipboard_copy_success", _params, socket) do
    {:noreply, put_flash(socket, :info, "Code copied to clipboard")}
  end

  @impl true
  def handle_event("clipboard_copy_error", _params, socket) do
    {:noreply, put_flash(socket, :error, "Failed to copy to clipboard")}
  end

  @impl true
  def handle_event("gallery_index_changed", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("aliases_page", %{"page" => page}, socket) do
    aliases = socket.assigns.gall.aliases
    page = max(1, min(page, aliases_total_pages(aliases, socket.assigns.aliases_page_size)))
    {:noreply, assign(socket, aliases_page: page)}
  end

  defp paginated_aliases(aliases, current_page, page_size) do
    aliases
    |> Enum.drop((current_page - 1) * page_size)
    |> Enum.take(page_size)
  end

  defp aliases_total_pages(aliases, page_size) do
    max(1, ceil(length(aliases) / page_size))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <%= if @error do %>
        <div class="bg-red-50 border border-red-200 rounded-lg p-4 text-red-700">{@error}</div>
      <% else %>
        <%= if @gall do %>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <div class="lg:col-span-2 space-y-2">
              <div class="flex items-start justify-between gap-4">
                <div class="flex items-center gap-2">
                  <h2 class="text-2xl font-bold"><em>{@gall.name}</em></h2>
                  <.link
                    :if={@current_user}
                    href={~p"/admin/galls/#{@gall.id}"}
                    class="text-gray-400 hover:text-gf-maroon"
                    title="Edit in admin"
                  >
                    <.icon name="ph-pencil-simple" class="h-5 w-5" />
                  </.link>
                </div>
                <.data_complete_badge
                  complete={@gall.datacomplete}
                  complete_tooltip="All sources containing unique information relevant to this gall have been added and are reflected in its associated data."
                  incomplete_tooltip="We are still working on this gall so data might be missing."
                />
              </div>

              <%= if @gall.undescribed do %>
                <div class="bg-amber-50 border border-amber-200 rounded-lg p-4">
                  <p class="text-red-600 font-medium mb-2">
                    The inducer of this gall is unknown or undescribed.
                  </p>
                  <p class="text-sm mb-2">
                    <span class="font-medium text-gray-700">Gallformers Code:</span>
                    <button
                      id="copy-gallformers-code"
                      phx-hook="CopyToClipboard"
                      data-copy-text={get_gallformers_code(@gall.name, @taxonomy && @taxonomy.genus)}
                      class="ml-1 cursor-pointer hover:opacity-70"
                    >
                      <code class="px-2 py-0.5 bg-white border border-amber-200 rounded font-mono text-amber-800">
                        {get_gallformers_code(@gall.name, @taxonomy && @taxonomy.genus)}
                      </code>
                      <span class="ml-2 text-xs hover:underline">
                        Click to Copy
                      </span>
                    </button>
                  </p>
                  <p class="text-sm text-gray-600">
                    Observations are tagged with this code on iNaturalist. You can view these observations with this <a
                      href={"https://www.inaturalist.org/observations?verifiable=any&place_id=any&field:Gallformers%20Code=#{URI.encode(get_gallformers_code(@gall.name, @taxonomy && @taxonomy.genus))}"}
                      target="_blank"
                      rel="noreferrer"
                      class="hover:underline"
                    >link</a>.
                  </p>
                </div>
              <% end %>

              <div class="flex flex-col md:flex-row md:items-start gap-4">
                <div class="flex-1 space-y-2">
                  <%= if @taxonomy do %>
                    <p>
                      <%= if @taxonomy.family do %>
                        <strong>Family:</strong>
                        <.link
                          href={"/family/#{@taxonomy.family_id}"}
                          class="hover:underline"
                        >
                          {@taxonomy.family}
                        </.link>
                      <% end %>
                      <%= if @taxonomy.family && @taxonomy.genus do %>
                        <span class="mx-1">|</span>
                      <% end %>
                      <%= if @taxonomy.genus do %>
                        <strong>Genus:</strong>
                        <.link
                          href={"/genus/#{@taxonomy.genus_id}"}
                          class="hover:underline"
                        >
                          <em>{@taxonomy.genus}</em>
                        </.link>
                      <% end %>
                    </p>
                  <% end %>

                  <%= if @gall.hosts && length(@gall.hosts) > 0 do %>
                    <div class="flex items-center gap-1">
                      <div>
                        <strong>Hosts:</strong>
                        <em>
                          <%= for {host, idx} <- Enum.with_index(@gall.hosts) do %>
                            {if idx > 0, do: " / "}<.link
                              href={"/host/#{host.host_species_id}"}
                              class="hover:underline"
                            >{host.host_name}</.link>
                          <% end %>
                        </em>
                      </div>
                      <.link
                        :if={@current_user}
                        href={~p"/admin/gallhost?id=#{@gall.id}"}
                        class="text-gray-400 hover:text-gf-maroon"
                        title="Edit gall-host mappings"
                      >
                        <.icon name="ph-pencil-simple" class="h-4 w-4" />
                      </.link>
                    </div>
                  <% end %>

                  <div class="grid grid-cols-1 md:grid-cols-2 gap-x-4">
                    <div class="space-y-1">
                      <div>
                        <strong>Detachable:</strong> {get_detachable_display(@gall.detachable)}
                      </div>
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
                  </div>
                </div>

                <div class="md:w-64 lg:w-80 shrink-0">
                  <div><strong>Possible Range:</strong></div>
                  <.range_map
                    id="gall-range-map"
                    in_range={MapSet.to_list(@range)}
                    excluded_range={MapSet.to_list(@excluded_range)}
                  />
                </div>
              </div>

              <%= if @gall.aliases && length(@gall.aliases) > 0 do %>
                <div class="mt-4">
                  <h3 class="font-semibold text-gray-800 mb-2">
                    Synonymy ({length(@gall.aliases)})
                  </h3>
                  <div class="bg-white rounded border border-gray-200 overflow-hidden">
                    <table class="gf-table gf-table-compact">
                      <thead>
                        <tr>
                          <th>Name</th>
                          <th>Type</th>
                          <th>Notes</th>
                        </tr>
                      </thead>
                      <tbody>
                        <%= for a <- paginated_aliases(@gall.aliases, @aliases_page, @aliases_page_size) do %>
                          <tr>
                            <td><em>{a.name}</em></td>
                            <td class="text-gray-600">{a.type || "—"}</td>
                            <td class="text-gray-600">{a.description || "—"}</td>
                          </tr>
                        <% end %>
                      </tbody>
                    </table>
                  </div>
                  <%= if aliases_total_pages(@gall.aliases, @aliases_page_size) > 1 do %>
                    <.pagination
                      page={@aliases_page}
                      total_pages={aliases_total_pages(@gall.aliases, @aliases_page_size)}
                      total_items={length(@gall.aliases)}
                      page_size={@aliases_page_size}
                      on_page_change={fn page -> JS.push("aliases_page", value: %{page: page}) end}
                      class="mt-4"
                    />
                  <% end %>
                </div>
              <% end %>
            </div>

            <div class="lg:col-span-1">
              <.image_gallery
                images={@images}
                id="gall-images"
                species_id={@gall.id}
                current_user={@current_user}
              />
            </div>
          </div>

          <hr class="border-gray-200 my-4" />

          <%= if @has_gallformers_notes && !@notes_alert_dismissed do %>
            <div
              class="flex items-center gap-3 p-3 mb-4 bg-white border border-blue-200 border-l-4 border-l-blue-400 rounded text-sm text-gray-700"
              role="alert"
            >
              <.icon name="ph-info" class="h-5 w-5 text-blue-500 shrink-0" />
              <p class="flex-1">
                Our ID Notes may contain important tips necessary for distinguishing this gall
                from similar galls and/or important information about the taxonomic status of
                this gall inducer.
              </p>
              <button
                type="button"
                class="text-gray-400 hover:text-gray-600"
                phx-click="dismiss_notes_alert"
                aria-label="Dismiss"
              >
                <.icon name="ph-x" class="h-4 w-4" />
              </button>
            </div>
          <% end %>

          <%= if length(@sources) > 0 do %>
            <h3 class="font-semibold mb-2">Further Information ({length(@sources)})</h3>
            <div class="space-y-2">
              <%= for source <- @sources do %>
                <div class={"p-3 rounded border bg-white #{if source.id == 58, do: "border-blue-200 border-l-4 border-l-blue-400", else: "border-gray-200"}"}>
                  <div>
                    <%= if source.id == 58 do %>
                      <.icon
                        name="ph-info"
                        class="h-5 w-5 text-blue-500 inline-block align-text-bottom mr-1"
                      />
                    <% end %>
                    <.link
                      href={"/source/#{source.id}"}
                      class="font-medium hover:underline"
                    >
                      {source.title}
                    </.link>
                    {if source.author, do: " - #{source.author}"}
                    {if source.pubyear, do: " (#{source.pubyear})"}
                    <%= if source.externallink do %>
                      <.link
                        href={source.externallink}
                        target="_blank"
                        rel="noopener noreferrer"
                        class="ml-2 hover:underline"
                      >
                        [Link]
                      </.link>
                    <% end %>
                    <.link
                      :if={@current_user}
                      href={
                        ~p"/admin/species-sources/find?species_id=#{@gall.id}&source_id=#{source.id}"
                      }
                      class="ml-2 text-gray-400 hover:text-gf-maroon"
                      title="Edit species-source mapping"
                    >
                      <.icon name="ph-pencil-simple" class="h-4 w-4 inline-block align-text-bottom" />
                    </.link>
                  </div>
                  <%= if source.description do %>
                    <div class="mt-1 text-gray-700 [&_p]:mb-2 [&_a]:text-gf-maroon [&_a]:underline">
                      {Phoenix.HTML.raw(Markdown.render!(source.description))}
                    </div>
                  <% end %>
                  <%= if source.license do %>
                    <p class="mt-1 text-sm text-gray-500">
                      License:
                      <%= if source.licenselink do %>
                        <.link
                          href={source.licenselink}
                          target="_blank"
                          rel="noopener noreferrer"
                          class="hover:underline"
                        >
                          {source.license}
                        </.link>
                      <% else %>
                        {source.license}
                      <% end %>
                    </p>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% else %>
            <p class="italic">No further information available for this species.</p>
          <% end %>

          <.see_also name={@gall.name} type={:gall} undescribed={@gall.undescribed} />
        <% else %>
          <div class="bg-red-50 border border-red-200 rounded-lg p-4 text-red-700">
            Gall not found
          </div>
        <% end %>
      <% end %>
    </Layouts.app>
    """
  end
end
