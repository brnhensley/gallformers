defmodule GallformersWeb.Layouts do
  @moduledoc """
  Layout components for Gallformers.

  Includes header with navigation, footer with links, and the main app layout.
  """
  use GallformersWeb, :html

  # Embed all files in layouts/* within this module.
  embed_templates "layouts/*"

  @doc """
  Renders the Gallformers app layout with header, main content, and footer.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="flex min-h-screen flex-col">
      <.site_header />

      <main class="flex-1 pb-32">
        <div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
          {render_slot(@inner_block)}
        </div>
      </main>

      <.site_footer />
    </div>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Renders the site header with logo, navigation, and search.

  Named `site_header` to avoid conflict with CoreComponents.header/1.
  """
  def site_header(assigns) do
    nav_links = [
      %{href: "/id", label: "Identify"},
      %{href: "/explore", label: "Explore"}
    ]

    resource_links = [
      %{href: "/filterguide", label: "Filter Terms"},
      %{href: "/glossary", label: "Glossary"},
      %{href: "/refindex", label: "Reference"}
    ]

    assigns =
      assigns
      |> assign(:nav_links, nav_links)
      |> assign(:resource_links, resource_links)

    ~H"""
    <header class="sticky top-0 z-50 bg-gf-sky-blue shadow-md">
      <nav class="px-3">
        <div class="flex items-center justify-between py-1">
          <%!-- Logo --%>
          <div class="flex-shrink-0">
            <a href="/" class="flex items-center">
              <img
                src="/branding/Wide Logo Versions/gallformers_logo_wide_color.png"
                alt="Gallformers logo: an oak gall wasp with a spherical oak gall and a white oak leaf"
                class="h-[70px]"
              />
            </a>
          </div>

          <%!-- Desktop Navigation --%>
          <div class="hidden md:flex md:items-center gap-1">
            <a
              :for={link <- @nav_links}
              href={link.href}
              class="px-2 text-lg font-medium !text-gf-maroon hover:underline"
            >
              {link.label}
            </a>

            <%!-- Search Form --%>
            <form action="/globalsearch" method="get" class="flex items-center">
              <input
                type="search"
                name="q"
                placeholder="Search"
                aria-label="Search"
                class="w-36 rounded-l-md border border-gf-maroon bg-white px-2 py-1 text-lg text-gray-900
                       placeholder:text-gray-400 focus:ring-2 focus:ring-gf-maroon focus:outline-none"
              />
              <button
                type="submit"
                class="rounded-r-md border border-gf-maroon bg-transparent px-2 py-1 text-lg
                       font-medium text-gf-maroon hover:bg-gf-maroon hover:text-white"
              >
                Search
              </button>
            </form>

            <%!-- Resources Dropdown --%>
            <div class="relative group">
              <button
                type="button"
                class="flex items-center px-2 text-lg font-medium text-gf-maroon hover:underline"
              >
                Resources
                <svg class="ml-1 h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M19 9l-7 7-7-7"
                  />
                </svg>
              </button>
              <div class="absolute right-0 z-10 mt-1 w-48 origin-top-right rounded-md bg-white py-1 shadow-lg
                          ring-1 ring-black ring-opacity-5 opacity-0 invisible group-hover:opacity-100
                          group-hover:visible transition-all duration-150">
                <a
                  :for={link <- @resource_links}
                  href={link.href}
                  class="block px-4 py-2 text-lg !text-gf-maroon hover:bg-gray-100"
                >
                  {link.label}
                </a>
              </div>
            </div>
          </div>

          <%!-- Mobile menu button --%>
          <div class="flex md:hidden">
            <button
              type="button"
              phx-click={toggle_mobile_menu()}
              class="inline-flex items-center justify-center rounded-md p-2 text-gf-maroon
                     hover:bg-white/50 focus:outline-none focus:ring-2 focus:ring-gf-maroon"
              aria-expanded="false"
              aria-controls="mobile-menu"
            >
              <span class="sr-only">Open main menu</span>
              <%!-- Hamburger icon --%>
              <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M4 6h16M4 12h16M4 18h16"
                />
              </svg>
            </button>
          </div>
        </div>

        <%!-- Mobile menu (hidden by default, toggle with JS) --%>
        <div class="hidden md:hidden" id="mobile-menu">
          <div class="space-y-1 px-2 pb-3 pt-2">
            <a
              :for={link <- @nav_links}
              href={link.href}
              class="block rounded-md px-3 py-2 text-lg font-medium !text-gf-maroon hover:bg-white/50"
            >
              {link.label}
            </a>

            <%!-- Mobile Search --%>
            <form action="/globalsearch" method="get" class="px-3 py-2">
              <div class="flex">
                <input
                  type="search"
                  name="q"
                  placeholder="Search"
                  aria-label="Search"
                  class="flex-1 rounded-l-md border border-gf-maroon bg-white px-3 py-2 text-lg text-gray-900
                         placeholder:text-gray-400 focus:ring-2 focus:ring-gf-maroon focus:outline-none"
                />
                <button
                  type="submit"
                  class="rounded-r-md border border-gf-maroon bg-transparent px-3 py-2 text-lg
                         font-medium text-gf-maroon hover:bg-gf-maroon hover:text-white"
                >
                  Search
                </button>
              </div>
            </form>

            <%!-- Mobile Resources --%>
            <div class="border-t border-gf-maroon/30 pt-2">
              <span class="block px-3 py-2 text-xs font-semibold uppercase tracking-wider text-gf-maroon/70">
                Resources
              </span>
              <a
                :for={link <- @resource_links}
                href={link.href}
                class="block rounded-md px-3 py-2 text-lg font-medium !text-gf-maroon hover:bg-white/50"
              >
                {link.label}
              </a>
            </div>
          </div>
        </div>
      </nav>
    </header>
    """
  end

  defp toggle_mobile_menu do
    JS.toggle(to: "#mobile-menu")
  end

  @doc """
  Renders the site footer with links and copyright.
  """
  def site_footer(assigns) do
    current_year = Date.utc_today().year

    assigns = assign(assigns, :current_year, current_year)

    ~H"""
    <footer class="fixed bottom-0 left-0 right-0 z-40 bg-gray-100 text-gf-maroon">
      <div class="flex items-center justify-between px-4 py-2">
        <%!-- Login - left side (desktop only) --%>
        <a
          href="/login"
          class="hidden sm:block text-base font-medium !text-gf-maroon hover:underline"
        >
          Login
        </a>

        <%!-- Copyright - center --%>
        <span class="hidden sm:block text-sm text-gray-600">
          &copy; {@current_year} Gallformers |
          <a
            href="https://creativecommons.org/licenses/by-nc-sa/4.0/"
            target="_blank"
            rel="noopener noreferrer"
            class="!text-gf-maroon hover:underline"
          >
            CC BY-NC-SA 4.0
          </a>
        </span>

        <%!-- Navigation Links - right side (desktop) --%>
        <nav class="hidden sm:flex items-center gap-x-4" aria-label="Footer navigation">
          <a
            href="https://megachile.shinyapps.io/doycalc/"
            target="_blank"
            rel="noopener noreferrer"
            class="text-base font-medium !text-gf-maroon hover:underline"
          >
            Phenology Tool
          </a>
          <a
            href="https://www.patreon.com/gallformers"
            target="_blank"
            rel="noopener noreferrer"
            class="text-base font-medium !text-gf-maroon hover:underline"
          >
            Donate
          </a>
          <a href="/about" class="text-base font-medium !text-gf-maroon hover:underline">
            About
          </a>
        </nav>

        <%!-- Mobile menu button --%>
        <button
          type="button"
          phx-click={toggle_footer_menu()}
          class="sm:hidden p-2 text-gf-maroon ml-auto"
          aria-label="Toggle footer menu"
        >
          <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M4 6h16M4 12h16M4 18h16"
            />
          </svg>
        </button>
      </div>

      <%!-- Mobile footer menu (hidden by default) --%>
      <div
        class="hidden sm:hidden absolute bottom-full left-0 right-0 bg-gray-100 py-3 border-t border-gray-300"
        id="footer-menu"
      >
        <a
          href="/login"
          class="block text-base font-medium !text-gf-maroon hover:underline py-1 px-4"
        >
          Login
        </a>
        <a
          href="https://megachile.shinyapps.io/doycalc/"
          target="_blank"
          rel="noopener noreferrer"
          class="block text-base font-medium !text-gf-maroon hover:underline py-1 px-4"
        >
          Phenology Tool
        </a>
        <a
          href="https://www.patreon.com/gallformers"
          target="_blank"
          rel="noopener noreferrer"
          class="block text-base font-medium !text-gf-maroon hover:underline py-1 px-4"
        >
          Donate
        </a>
        <a href="/about" class="block text-base font-medium !text-gf-maroon hover:underline py-1 px-4">
          About
        </a>
        <%!-- Copyright in mobile menu --%>
        <span class="block text-sm text-gray-600 py-1 px-4 mt-2 border-t border-gray-300 pt-2">
          &copy; {@current_year} Gallformers |
          <a
            href="https://creativecommons.org/licenses/by-nc-sa/4.0/"
            target="_blank"
            rel="noopener noreferrer"
            class="!text-gf-maroon hover:underline"
          >
            CC BY-NC-SA 4.0
          </a>
        </span>
      </div>
    </footer>
    """
  end

  defp toggle_footer_menu do
    JS.toggle(to: "#footer-menu")
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
