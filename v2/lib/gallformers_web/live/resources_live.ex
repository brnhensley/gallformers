defmodule GallformersWeb.ResourcesLive do
  @moduledoc """
  LiveView for the resources page.

  Displays external resources and links for learning about plant galls.
  """
  use GallformersWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Resources",
       page_description:
         "External resources for learning about plant galls - identification tools, databases, learning materials, and community links.",
       page_url: "/resources",
       page_image: nil,
       page_json_ld: nil
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="mx-auto max-w-4xl">
        <h1 class="text-3xl font-bold text-gf-maroon mb-8">Resources</h1>

        <p class="text-gray-700 mb-8">
          A collection of external resources for learning more about galls, their inducers, and the field of cecidiology.
        </p>

        <%!-- Identification Tools --%>
        <section class="mb-10">
          <h2 class="text-2xl font-semibold text-gray-800 mb-4">Identification Tools</h2>
          <div class="bg-white rounded-lg shadow-md divide-y">
            <div class="p-4">
              <.link href="/id" class="text-gf-maroon hover:underline font-medium">
                Gallformers ID Tool
              </.link>
              <p class="text-gray-600 text-sm mt-1">
                Our interactive gall identification tool - filter by host, location, characteristics, and more.
              </p>
            </div>
            <div class="p-4">
              <.link
                href="https://megachile.shinyapps.io/doycalc/"
                target="_blank"
                rel="noreferrer"
                class="text-gf-maroon hover:underline font-medium"
              >
                Gall Phenology Tool
              </.link>
              <p class="text-gray-600 text-sm mt-1">
                Explore the seasonal timing of gall development and emergence.
              </p>
            </div>
          </div>
        </section>

        <%!-- Online Databases --%>
        <section class="mb-10">
          <h2 class="text-2xl font-semibold text-gray-800 mb-4">Online Databases</h2>
          <div class="bg-white rounded-lg shadow-md divide-y">
            <div class="p-4">
              <.link
                href="https://www.inaturalist.org"
                target="_blank"
                rel="noreferrer"
                class="text-gf-maroon hover:underline font-medium"
              >
                iNaturalist
              </.link>
              <p class="text-gray-600 text-sm mt-1">
                Citizen science platform for recording and sharing observations of galls and other organisms.
              </p>
            </div>
            <div class="p-4">
              <.link
                href="https://bugguide.net"
                target="_blank"
                rel="noreferrer"
                class="text-gf-maroon hover:underline font-medium"
              >
                BugGuide
              </.link>
              <p class="text-gray-600 text-sm mt-1">
                Identification and information resource for insects, spiders, and related organisms in the US and Canada.
              </p>
            </div>
            <div class="p-4">
              <.link
                href="https://www.biodiversitylibrary.org"
                target="_blank"
                rel="noreferrer"
                class="text-gf-maroon hover:underline font-medium"
              >
                Biodiversity Heritage Library
              </.link>
              <p class="text-gray-600 text-sm mt-1">
                Digital archive of historical biodiversity literature, including many classic works on galls.
              </p>
            </div>
            <div class="p-4">
              <.link
                href="https://scholar.google.com"
                target="_blank"
                rel="noreferrer"
                class="text-gf-maroon hover:underline font-medium"
              >
                Google Scholar
              </.link>
              <p class="text-gray-600 text-sm mt-1">
                Search academic literature on gall biology, taxonomy, and ecology.
              </p>
            </div>
          </div>
        </section>

        <%!-- Learning Resources --%>
        <section class="mb-10">
          <h2 class="text-2xl font-semibold text-gray-800 mb-4">Learning Resources</h2>
          <div class="bg-white rounded-lg shadow-md divide-y">
            <div class="p-4">
              <.link href="/glossary" class="text-gf-maroon hover:underline font-medium">
                Gallformers Glossary
              </.link>
              <p class="text-gray-600 text-sm mt-1">
                Definitions of terms commonly used in gall biology and taxonomy.
              </p>
            </div>
            <div class="p-4">
              <.link href="/filterguide" class="text-gf-maroon hover:underline font-medium">
                Filter Guide
              </.link>
              <p class="text-gray-600 text-sm mt-1">
                Guide to the filter terms used in our ID tool.
              </p>
            </div>
            <div class="p-4">
              <.link href="/refindex" class="text-gf-maroon hover:underline font-medium">
                Reference Articles
              </.link>
              <p class="text-gray-600 text-sm mt-1">
                In-depth articles on gall biology and identification.
              </p>
            </div>
          </div>
        </section>

        <%!-- Community --%>
        <section class="mb-10">
          <h2 class="text-2xl font-semibold text-gray-800 mb-4">Community</h2>
          <div class="bg-white rounded-lg shadow-md divide-y">
            <div class="p-4">
              <.link
                href="https://www.inaturalist.org/projects/galls-of-north-america"
                target="_blank"
                rel="noreferrer"
                class="text-gf-maroon hover:underline font-medium"
              >
                Galls of North America (iNaturalist Project)
              </.link>
              <p class="text-gray-600 text-sm mt-1">
                iNaturalist umbrella project collecting gall observations from across North America.
              </p>
            </div>
            <div class="p-4">
              <.link
                href="https://twitter.com/gallformers"
                target="_blank"
                rel="noreferrer"
                class="text-gf-maroon hover:underline font-medium"
              >
                @gallformers on Twitter
              </.link>
              <p class="text-gray-600 text-sm mt-1">
                Follow us for updates, featured galls, and gall-related news.
              </p>
            </div>
            <div class="p-4">
              <.link
                href="https://www.patreon.com/gallformers"
                target="_blank"
                rel="noreferrer"
                class="text-gf-maroon hover:underline font-medium"
              >
                Gallformers Patreon
              </.link>
              <p class="text-gray-600 text-sm mt-1">
                Support the ongoing development and maintenance of Gallformers.
              </p>
            </div>
          </div>
        </section>

        <%!-- Related Projects --%>
        <section class="mb-10">
          <h2 class="text-2xl font-semibold text-gray-800 mb-4">Related Projects</h2>
          <div class="bg-white rounded-lg shadow-md divide-y">
            <div class="p-4">
              <.link
                href="https://github.com/jeffdc/gallformers"
                target="_blank"
                rel="noreferrer"
                class="text-gf-maroon hover:underline font-medium"
              >
                Gallformers on GitHub
              </.link>
              <p class="text-gray-600 text-sm mt-1">
                View the source code, report issues, or contribute to the project.
              </p>
            </div>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
