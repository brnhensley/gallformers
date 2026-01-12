defmodule GallformersWeb.DataDisplayComponents do
  @moduledoc """
  Data display components for the Gallformers application.

  Provides components for displaying species data, images, taxonomy,
  sources, and other domain-specific information.
  """
  use Phoenix.Component
  use Gettext, backend: GallformersWeb.Gettext

  import GallformersWeb.CoreComponents, only: [icon: 1]

  @doc """
  Renders an image gallery with lightbox support.

  ## Examples

      <.image_gallery images={@images} />

      <.image_gallery images={@images} show_attribution />
  """
  attr :images, :list,
    required: true,
    doc: "list of image maps with :src, :alt, :creator, :license keys"

  attr :show_attribution, :boolean, default: true, doc: "whether to show attribution info"
  attr :class, :any, default: nil, doc: "additional CSS classes"
  attr :id, :string, default: "image-gallery", doc: "unique id for the gallery"

  def image_gallery(assigns) do
    images_json =
      assigns.images
      |> Enum.map(fn img ->
        %{
          src: Map.get(img, :src) || Map.get(img, "src"),
          alt: Map.get(img, :alt) || Map.get(img, "alt") || ""
        }
      end)
      |> Jason.encode!()

    first_image = List.first(assigns.images) || %{}

    assigns =
      assigns
      |> assign(:images_json, images_json)
      |> assign(:first_image, first_image)
      |> assign(:image_count, length(assigns.images))

    ~H"""
    <div
      :if={@image_count > 0}
      id={@id}
      class={["relative", @class]}
      phx-hook="ImageGallery"
      phx-update="ignore"
      data-images={@images_json}
      tabindex="0"
    >
      <div class="relative aspect-[4/3] bg-gray-100 rounded-lg overflow-hidden">
        <img
          data-main-image
          src={@first_image[:src] || @first_image["src"]}
          alt={@first_image[:alt] || @first_image["alt"] || ""}
          class="w-full h-full object-contain cursor-pointer"
          loading="lazy"
          data-open-lightbox
        />

        <button
          :if={@image_count > 1}
          type="button"
          data-prev
          class="absolute left-2 top-1/2 -translate-y-1/2 p-2 rounded-full bg-black/40 hover:bg-black/60 text-white transition-colors"
          aria-label={gettext("Previous image")}
        >
          <.icon name="hero-chevron-left" class="size-5" />
        </button>

        <button
          :if={@image_count > 1}
          type="button"
          data-next
          class="absolute right-2 top-1/2 -translate-y-1/2 p-2 rounded-full bg-black/40 hover:bg-black/60 text-white transition-colors"
          aria-label={gettext("Next image")}
        >
          <.icon name="hero-chevron-right" class="size-5" />
        </button>

        <div
          :if={@image_count > 1}
          data-counter
          class="absolute bottom-2 left-1/2 -translate-x-1/2 px-2 py-1 rounded bg-black/60 text-white text-sm"
        >
          1 / {@image_count}
        </div>
      </div>

      <div
        :if={@show_attribution}
        class="mt-2 flex items-center justify-between text-sm text-gray-600"
      >
        <span :if={@first_image[:creator] || @first_image["creator"]}>
          {gettext("Photo by")} {@first_image[:creator] || @first_image["creator"]}
        </span>
        <span :if={@first_image[:license] || @first_image["license"]}>
          {@first_image[:license] || @first_image["license"]}
        </span>
      </div>

      <dialog
        data-lightbox
        class="w-screen h-screen max-w-none p-0 bg-black/90 backdrop:bg-transparent"
      >
        <div class="w-full h-full flex flex-col items-center justify-center p-4">
          <button
            type="button"
            data-close-lightbox
            class="absolute top-4 right-4 p-2 rounded-full bg-white/20 hover:bg-white/30 text-white"
            aria-label={gettext("Close")}
          >
            <.icon name="hero-x-mark" class="size-6" />
          </button>

          <img
            data-lightbox-image
            src={@first_image[:src] || @first_image["src"]}
            alt={@first_image[:alt] || @first_image["alt"] || ""}
            class="max-w-full max-h-[80vh] object-contain"
          />

          <div :if={@image_count > 1} class="mt-4 flex items-center gap-4">
            <button
              type="button"
              data-prev
              class="p-3 rounded-full bg-white/20 hover:bg-white/30 text-white"
              aria-label={gettext("Previous image")}
            >
              <.icon name="hero-chevron-left" class="size-6" />
            </button>
            <span data-counter class="text-white text-lg">1 / {@image_count}</span>
            <button
              type="button"
              data-next
              class="p-3 rounded-full bg-white/20 hover:bg-white/30 text-white"
              aria-label={gettext("Next image")}
            >
              <.icon name="hero-chevron-right" class="size-6" />
            </button>
          </div>
        </div>
      </dialog>
    </div>

    <div
      :if={@image_count == 0}
      class="aspect-[4/3] bg-gray-100 rounded-lg flex items-center justify-center"
    >
      <div class="text-gray-400 text-center">
        <.icon name="hero-photo" class="size-12 mx-auto mb-2" />
        <p>{gettext("No images available")}</p>
      </div>
    </div>
    """
  end

  @doc """
  Renders a species card for list views.

  ## Examples

      <.species_card species={@species} />
  """
  attr :species, :map,
    required: true,
    doc: "species data with :id, :name, :description, :image keys"

  attr :href, :string, default: nil, doc: "link to the species detail page"
  attr :class, :any, default: nil, doc: "additional CSS classes"

  def species_card(assigns) do
    ~H"""
    <div class={[
      "bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden hover:shadow-md transition-shadow",
      @class
    ]}>
      <.link :if={@href} navigate={@href} class="block">
        <div class="aspect-[4/3] bg-gray-100">
          <img
            :if={@species[:image] || @species["image"]}
            src={@species[:image] || @species["image"]}
            alt={@species[:name] || @species["name"]}
            class="w-full h-full object-cover"
            loading="lazy"
          />
          <div
            :if={!(@species[:image] || @species["image"])}
            class="w-full h-full flex items-center justify-center text-gray-400"
          >
            <.icon name="hero-photo" class="size-12" />
          </div>
        </div>
        <div class="p-4">
          <h3 class="text-lg font-medium text-gf-maroon hover:underline">
            <em>{@species[:name] || @species["name"]}</em>
          </h3>
          <p
            :if={@species[:description] || @species["description"]}
            class="mt-1 text-sm text-gray-600 line-clamp-2"
          >
            {@species[:description] || @species["description"]}
          </p>
        </div>
      </.link>
      <div :if={!@href}>
        <div class="aspect-[4/3] bg-gray-100">
          <img
            :if={@species[:image] || @species["image"]}
            src={@species[:image] || @species["image"]}
            alt={@species[:name] || @species["name"]}
            class="w-full h-full object-cover"
            loading="lazy"
          />
          <div
            :if={!(@species[:image] || @species["image"])}
            class="w-full h-full flex items-center justify-center text-gray-400"
          >
            <.icon name="hero-photo" class="size-12" />
          </div>
        </div>
        <div class="p-4">
          <h3 class="text-lg font-medium text-gf-maroon">
            <em>{@species[:name] || @species["name"]}</em>
          </h3>
          <p
            :if={@species[:description] || @species["description"]}
            class="mt-1 text-sm text-gray-600 line-clamp-2"
          >
            {@species[:description] || @species["description"]}
          </p>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a list of host plants.

  ## Examples

      <.host_list hosts={@hosts} />
  """
  attr :hosts, :list, required: true, doc: "list of host maps with :id, :name, :genus keys"
  attr :class, :any, default: nil, doc: "additional CSS classes"

  def host_list(assigns) do
    ~H"""
    <ul :if={@hosts != []} class={["space-y-1", @class]}>
      <li :for={host <- @hosts} class="flex items-center gap-2">
        <.icon name="hero-leaf" class="size-4 text-green-600 flex-shrink-0" />
        <.link
          :if={host[:id] || host["id"]}
          navigate={"/host/#{host[:id] || host["id"]}"}
          class="hover:underline"
        >
          <em>{host[:name] || host["name"]}</em>
          <span :if={host[:common_name] || host["common_name"]} class="text-gray-600 ml-1">
            ({host[:common_name] || host["common_name"]})
          </span>
        </.link>
        <span :if={!(host[:id] || host["id"])}>
          <em>{host[:name] || host["name"]}</em>
          <span :if={host[:common_name] || host["common_name"]} class="text-gray-600 ml-1">
            ({host[:common_name] || host["common_name"]})
          </span>
        </span>
      </li>
    </ul>
    <p :if={@hosts == []} class="text-gray-500 italic">
      {gettext("No host plants recorded")}
    </p>
    """
  end

  @doc """
  Renders a source citation.

  ## Examples

      <.source_citation source={@source} />
  """
  attr :source, :map, required: true, doc: "source data with :title, :author, :year, :url keys"
  attr :class, :any, default: nil, doc: "additional CSS classes"

  def source_citation(assigns) do
    ~H"""
    <div class={["text-sm", @class]}>
      <span :if={@source[:author] || @source["author"]} class="font-medium">
        {@source[:author] || @source["author"]}.
      </span>
      <span :if={@source[:year] || @source["year"]}>
        ({@source[:year] || @source["year"]}).
      </span>
      <span :if={@source[:title] || @source["title"]}>
        <.link
          :if={@source[:url] || @source["url"]}
          href={@source[:url] || @source["url"]}
          target="_blank"
          rel="noopener noreferrer"
          class="text-blue-600 hover:underline"
        >
          {@source[:title] || @source["title"]}
          <.icon name="hero-arrow-top-right-on-square" class="size-3 inline ml-0.5" />
        </.link>
        <span :if={!(@source[:url] || @source["url"])}>
          {@source[:title] || @source["title"]}
        </span>
      </span>
      <span :if={@source[:publication] || @source["publication"]} class="italic">
        {@source[:publication] || @source["publication"]}.
      </span>
    </div>
    """
  end

  @doc """
  Renders a taxonomy breadcrumb showing the taxonomic hierarchy.

  ## Examples

      <.taxonomy_breadcrumb family={@family} genus={@genus} species={@species} />
  """
  attr :family, :map, default: nil, doc: "family data with :id, :name keys"
  attr :genus, :map, default: nil, doc: "genus data with :id, :name, :description keys"
  attr :species, :map, default: nil, doc: "species name (for display only)"
  attr :show_family, :boolean, default: true, doc: "whether to show family"
  attr :show_genus, :boolean, default: true, doc: "whether to show genus"
  attr :class, :any, default: nil, doc: "additional CSS classes"

  def taxonomy_breadcrumb(assigns) do
    ~H"""
    <div class={["flex flex-wrap items-center gap-1 text-sm", @class]}>
      <span :if={@show_family && @family} class="flex items-center gap-1">
        <strong>{gettext("Family:")}</strong>
        <.link
          :if={@family[:id] || @family["id"]}
          navigate={"/family/#{@family[:id] || @family["id"]}"}
          class="hover:underline"
        >
          {@family[:name] || @family["name"]}
        </.link>
        <span :if={!(@family[:id] || @family["id"])}>
          {@family[:name] || @family["name"]}
        </span>
      </span>

      <span :if={@show_family && @family && @show_genus && @genus} class="mx-1 text-gray-400">|</span>

      <span :if={@show_genus && @genus} class="flex items-center gap-1">
        <strong>{gettext("Genus:")}</strong>
        <.link
          :if={@genus[:id] || @genus["id"]}
          navigate={"/genus/#{@genus[:id] || @genus["id"]}"}
          class="hover:underline"
        >
          <em>{@genus[:name] || @genus["name"]}</em>
          <span :if={@genus[:description] || @genus["description"]} class="text-gray-600 not-italic">
            - {@genus[:description] || @genus["description"]}
          </span>
        </.link>
        <span :if={!(@genus[:id] || @genus["id"])}>
          <em>{@genus[:name] || @genus["name"]}</em>
          <span :if={@genus[:description] || @genus["description"]} class="text-gray-600 not-italic">
            - {@genus[:description] || @genus["description"]}
          </span>
        </span>
      </span>

      <span
        :if={((@show_family && @family) || (@show_genus && @genus)) && @species}
        class="mx-1 text-gray-400"
      >
        |
      </span>

      <span :if={@species} class="flex items-center gap-1">
        <strong>{gettext("Species:")}</strong>
        <em>{@species[:name] || @species["name"] || @species}</em>
      </span>
    </div>
    """
  end

  @doc """
  Renders a data completeness indicator.

  Shows whether data for an entity is complete or has missing information.

  ## Examples

      <.data_completeness_indicator complete={true} />
      <.data_completeness_indicator complete={false} missing={["hosts", "description"]} />
  """
  attr :complete, :boolean, required: true, doc: "whether the data is complete"
  attr :missing, :list, default: [], doc: "list of missing fields"
  attr :class, :any, default: nil, doc: "additional CSS classes"

  def data_completeness_indicator(assigns) do
    ~H"""
    <span class={["relative inline-flex group", @class]}>
      <button
        type="button"
        class="px-2 py-1 text-lg border border-gray-300 rounded bg-white hover:bg-gray-50"
        aria-label={if @complete, do: gettext("Data complete"), else: gettext("Data incomplete")}
      >
        {if @complete, do: "💯", else: "❓"}
      </button>
      <div
        class="absolute z-50 hidden group-hover:block left-full top-1/2 -translate-y-1/2 ml-2 w-64 px-3 py-2 text-sm bg-gray-900 text-white rounded-md shadow-lg"
        role="tooltip"
      >
        <span :if={@complete}>
          {gettext("All data fields are complete")}
        </span>
        <div :if={!@complete}>
          <p class="font-medium mb-1">{gettext("Missing information:")}</p>
          <ul class="list-disc list-inside">
            <li :for={field <- @missing}>{field}</li>
          </ul>
          <p :if={@missing == []} class="italic">
            {gettext("Some data may be incomplete")}
          </p>
        </div>
        <div class="absolute right-full top-1/2 -translate-y-1/2 w-0 h-0 border-4 border-r-gray-900 border-y-transparent border-l-transparent" />
      </div>
    </span>
    """
  end

  @doc """
  Renders an edit button for admin users.

  ## Examples

      <.edit_button href="/admin/species/123/edit" />
      <.edit_button href="/admin/species/123/edit" label="Edit Species" />
  """
  attr :href, :string, required: true, doc: "link to the edit page"
  attr :label, :string, default: nil, doc: "optional button label"
  attr :class, :any, default: nil, doc: "additional CSS classes"

  def edit_button(assigns) do
    ~H"""
    <.link
      navigate={@href}
      class={[
        "inline-flex items-center gap-1 px-3 py-1.5 text-sm font-medium rounded-md",
        "bg-gf-maroon text-white hover:bg-gf-maroon/90 transition-colors",
        @class
      ]}
    >
      <.icon name="hero-pencil-square" class="size-4" />
      <span :if={@label}>{@label}</span>
      <span :if={!@label}>{gettext("Edit")}</span>
    </.link>
    """
  end

  @doc """
  Renders external links for a species (iNaturalist, BugGuide, etc).

  ## Examples

      <.external_links links={@external_links} />
  """
  attr :links, :list, required: true, doc: "list of link maps with :name, :url keys"
  attr :class, :any, default: nil, doc: "additional CSS classes"

  def external_links(assigns) do
    ~H"""
    <div :if={@links != []} class={["flex flex-wrap gap-2", @class]}>
      <.link
        :for={link <- @links}
        href={link[:url] || link["url"]}
        target="_blank"
        rel="noopener noreferrer"
        class="inline-flex items-center gap-1 px-3 py-1.5 text-sm rounded-full border border-gray-300 hover:bg-gray-50 transition-colors"
      >
        {link[:name] || link["name"]}
        <.icon name="hero-arrow-top-right-on-square" class="size-3" />
      </.link>
    </div>
    """
  end

  @doc """
  Renders a source list.

  ## Examples

      <.source_list sources={@sources} />
  """
  attr :sources, :list, required: true, doc: "list of source maps"
  attr :class, :any, default: nil, doc: "additional CSS classes"

  def source_list(assigns) do
    ~H"""
    <ul :if={@sources != []} class={["space-y-3", @class]}>
      <li :for={source <- @sources}>
        <.source_citation source={source} />
      </li>
    </ul>
    <p :if={@sources == []} class="text-gray-500 italic">
      {gettext("No sources available")}
    </p>
    """
  end

  @doc """
  Renders species synonymy information.

  ## Examples

      <.species_synonymy aliases={@aliases} />
  """
  attr :aliases, :list, required: true, doc: "list of alias/synonym names"
  attr :class, :any, default: nil, doc: "additional CSS classes"

  def species_synonymy(assigns) do
    ~H"""
    <div :if={@aliases != []} class={@class}>
      <h4 class="text-sm font-medium text-gray-700 mb-1">{gettext("Also known as:")}</h4>
      <ul class="flex flex-wrap gap-2">
        <li
          :for={alias_name <- @aliases}
          class="px-2 py-0.5 bg-gray-100 rounded text-sm italic"
        >
          {alias_name}
        </li>
      </ul>
    </div>
    """
  end

  @doc """
  Renders an abundance indicator.

  ## Examples

      <.abundance_indicator level="common" />
  """
  attr :level, :string, required: true, doc: "abundance level (common, uncommon, rare, etc)"
  attr :class, :any, default: nil, doc: "additional CSS classes"

  def abundance_indicator(assigns) do
    level_styles = %{
      "common" => %{bg: "bg-green-100", text: "text-green-800"},
      "uncommon" => %{bg: "bg-yellow-100", text: "text-yellow-800"},
      "rare" => %{bg: "bg-orange-100", text: "text-orange-800"},
      "very rare" => %{bg: "bg-red-100", text: "text-red-800"},
      "unknown" => %{bg: "bg-gray-100", text: "text-gray-800"}
    }

    styles = Map.get(level_styles, String.downcase(assigns.level), level_styles["unknown"])
    assigns = assign(assigns, :styles, styles)

    ~H"""
    <span class={[
      "inline-flex items-center px-2 py-0.5 rounded text-sm font-medium",
      @styles.bg,
      @styles.text,
      @class
    ]}>
      {@level}
    </span>
    """
  end

  @doc """
  Renders a geographic range map showing US and Canadian states/provinces.

  Uses D3.js for SVG-based choropleth rendering. Displays regions in green if
  in range, coral if excluded, and white otherwise.

  ## Examples

      <.range_map in_range={["CA", "TX", "NY"]} />

      <.range_map in_range={["CA", "TX"]} excluded_range={["AZ"]} />

      <.range_map in_range={@places} editable on_toggle={JS.push("toggle_region")} />
  """
  attr :in_range, :list,
    required: true,
    doc: "list of postal codes in range (e.g., [\"CA\", \"TX\"])"

  attr :excluded_range, :list,
    default: [],
    doc: "list of postal codes explicitly excluded"

  attr :editable, :boolean,
    default: false,
    doc: "whether regions are clickable for editing"

  attr :id, :string,
    default: "range-map",
    doc: "unique id for the map element"

  attr :class, :any,
    default: nil,
    doc: "additional CSS classes"

  def range_map(assigns) do
    in_range_json = Jason.encode!(assigns.in_range)
    excluded_range_json = Jason.encode!(assigns.excluded_range)

    assigns =
      assigns
      |> assign(:in_range_json, in_range_json)
      |> assign(:excluded_range_json, excluded_range_json)

    ~H"""
    <div
      id={@id}
      class={["relative", @class]}
      phx-hook="RangeMap"
      phx-update="ignore"
      data-in-range={@in_range_json}
      data-excluded-range={@excluded_range_json}
      data-editable={to_string(@editable)}
    >
      <div class="flex items-center justify-center p-8 text-gray-500">
        <.icon name="hero-map" class="size-8 animate-pulse" />
        <span class="ml-2">{gettext("Loading map...")}</span>
      </div>
    </div>
    """
  end
end
