defmodule GallformersWeb.SEO do
  @moduledoc """
  SEO components for meta tags, Open Graph, and structured data.

  These components render meta tags in the document head for improved
  search engine optimization and social media sharing.
  """
  use Phoenix.Component

  @base_url "https://gallformers.org"
  @site_name "Gallformers"
  @default_image "/images/cynipid_R.svg"
  @default_description "Gallformers - A comprehensive database of plant galls and their causative organisms"

  @doc """
  Returns the base URL for the site.
  """
  def base_url, do: @base_url

  @doc """
  Renders meta tags for SEO including title, description, and canonical URL.

  ## Attributes

    * `:title` - The page title (will be appended with " | Gallformers")
    * `:description` - The meta description for the page
    * `:canonical` - The canonical URL path (without base URL)
    * `:noindex` - If true, adds noindex directive (default: false)

  ## Examples

      <SEO.meta_tags
        title="Oak Apple Gall"
        description="Detailed information about the oak apple gall"
        canonical="/gall/123"
      />
  """
  attr :title, :string, default: nil
  attr :description, :string, default: nil
  attr :canonical, :string, default: nil
  attr :noindex, :boolean, default: false

  def meta_tags(assigns) do
    ~H"""
    <meta name="description" content={@description || @default_description} />
    <meta :if={@canonical} name="canonical" content={build_url(@canonical)} />
    <meta :if={@noindex} name="robots" content="noindex, nofollow" />
    """
  end

  @doc """
  Renders Open Graph meta tags for social media sharing.

  ## Attributes

    * `:title` - The OG title (defaults to page title)
    * `:description` - The OG description
    * `:url` - The canonical URL path
    * `:image` - The OG image URL (defaults to site logo)
    * `:type` - The OG type (default: "website")

  ## Examples

      <SEO.og_tags
        title="Oak Apple Gall"
        description="Detailed information about the oak apple gall"
        url="/gall/123"
        image="https://example.com/image.jpg"
      />
  """
  attr :title, :string, default: nil
  attr :description, :string, default: nil
  attr :url, :string, default: nil
  attr :image, :string, default: nil
  attr :type, :string, default: "website"

  def og_tags(assigns) do
    title = if assigns[:title], do: "#{assigns[:title]} | #{@site_name}", else: @site_name
    description = assigns[:description] || @default_description
    image = assigns[:image] || "#{@base_url}#{@default_image}"

    assigns =
      assigns
      |> assign(:full_title, title)
      |> assign(:full_description, description)
      |> assign(:full_image, image)
      |> assign(:site_name, @site_name)

    ~H"""
    <meta property="og:title" content={@full_title} />
    <meta property="og:description" content={@full_description} />
    <meta property="og:type" content={@type} />
    <meta :if={@url} property="og:url" content={build_url(@url)} />
    <meta property="og:image" content={@full_image} />
    <meta property="og:site_name" content={@site_name} />
    <%!-- Twitter Card tags --%>
    <meta name="twitter:card" content="summary_large_image" />
    <meta name="twitter:title" content={@full_title} />
    <meta name="twitter:description" content={@full_description} />
    <meta name="twitter:image" content={@full_image} />
    """
  end

  @doc """
  Renders JSON-LD structured data for a species/gall page.

  ## Attributes

    * `:name` - The species name
    * `:description` - Description of the species
    * `:url` - The canonical URL path
    * `:image` - Primary image URL
    * `:scientific_name` - Scientific name (usually same as name)

  ## Examples

      <SEO.species_json_ld
        name="Amphibolips confluenta"
        description="The oak apple gall..."
        url="/gall/123"
        image="https://example.com/image.jpg"
      />
  """
  attr :name, :string, required: true
  attr :description, :string, default: nil
  attr :url, :string, required: true
  attr :image, :string, default: nil
  attr :scientific_name, :string, default: nil

  def species_json_ld(assigns) do
    json_ld = %{
      "@context" => "https://schema.org",
      "@type" => "Thing",
      "name" => assigns[:name],
      "description" =>
        assigns[:description] || "#{assigns[:name]} - A gall species documented on Gallformers.",
      "url" => build_url(assigns[:url]),
      "identifier" => assigns[:scientific_name] || assigns[:name]
    }

    # Add image if provided
    json_ld =
      if assigns[:image] do
        Map.put(json_ld, "image", assigns[:image])
      else
        json_ld
      end

    assigns = assign(assigns, :json_ld, Jason.encode!(json_ld))

    ~H"""
    <script type="application/ld+json">
      {Phoenix.HTML.raw(@json_ld)}
    </script>
    """
  end

  @doc """
  Renders JSON-LD structured data for the website/organization.

  Used on the home page and other general pages.
  """
  def website_json_ld(assigns) do
    json_ld = %{
      "@context" => "https://schema.org",
      "@type" => "WebSite",
      "name" => @site_name,
      "url" => @base_url,
      "description" => @default_description,
      "potentialAction" => %{
        "@type" => "SearchAction",
        "target" => %{
          "@type" => "EntryPoint",
          "urlTemplate" => "#{@base_url}/globalsearch?q={search_term_string}"
        },
        "query-input" => "required name=search_term_string"
      }
    }

    assigns = assign(assigns, :json_ld, Jason.encode!(json_ld))

    ~H"""
    <script type="application/ld+json">
      {Phoenix.HTML.raw(@json_ld)}
    </script>
    """
  end

  @doc """
  Renders a complete SEO head block with all meta tags.

  This is a convenience component that combines meta_tags, og_tags,
  and optionally JSON-LD in one call.

  ## Attributes

    * `:title` - The page title
    * `:description` - The meta description
    * `:url` - The canonical URL path
    * `:image` - The OG/Twitter image URL
    * `:type` - The OG type (default: "website")
    * `:noindex` - If true, adds noindex directive

  ## Examples

      <SEO.head
        title="Oak Apple Gall"
        description="Detailed information..."
        url="/gall/123"
      />
  """
  attr :title, :string, default: nil
  attr :description, :string, default: nil
  attr :url, :string, default: nil
  attr :image, :string, default: nil
  attr :type, :string, default: "website"
  attr :noindex, :boolean, default: false

  def head(assigns) do
    ~H"""
    <.meta_tags title={@title} description={@description} canonical={@url} noindex={@noindex} />
    <.og_tags title={@title} description={@description} url={@url} image={@image} type={@type} />
    """
  end

  # Helper to build full URLs from paths
  defp build_url(nil), do: nil
  defp build_url("http" <> _ = url), do: url
  defp build_url("/" <> _ = path), do: @base_url <> path
  defp build_url(path), do: @base_url <> "/" <> path
end
