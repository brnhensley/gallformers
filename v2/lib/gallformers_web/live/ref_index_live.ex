defmodule GallformersWeb.RefIndexLive do
  @moduledoc """
  LiveView for the reference library index page.

  Currently displays a "Coming Soon" placeholder with information about
  what to expect when the reference articles are available.
  """
  use GallformersWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Reference Library | Gallformers")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="mx-auto max-w-4xl">
        <h1 class="text-3xl font-bold text-gf-maroon mb-8">The Gallformers Reference Library</h1>

        <div class="bg-gf-maroon rounded-lg p-8 text-white text-center">
          <div class="mb-4">
            <svg class="w-16 h-16 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"
              />
            </svg>
          </div>
          <h2 class="text-2xl font-semibold mb-4">Coming Soon</h2>
          <p class="text-lg opacity-90 mb-6">
            We're working on bringing our reference articles to the new Gallformers site.
            In the meantime, you can explore our other resources.
          </p>
          <div class="flex flex-col sm:flex-row gap-4 justify-center">
            <.link
              href="/glossary"
              class="inline-block px-6 py-3 bg-white text-gf-maroon font-medium rounded-lg hover:bg-gray-100 transition-colors"
            >
              Browse Glossary
            </.link>
            <.link
              href="/filterguide"
              class="inline-block px-6 py-3 border-2 border-white text-white font-medium rounded-lg hover:bg-white/10 transition-colors"
            >
              Filter Guide
            </.link>
          </div>
        </div>

        <div class="mt-8 bg-gray-50 rounded-lg p-6">
          <h3 class="text-lg font-semibold text-gray-800 mb-4">What to expect</h3>
          <p class="text-gray-600 mb-4">
            The Reference Library will include in-depth articles covering:
          </p>
          <ul class="list-disc list-inside text-gray-600 space-y-2">
            <li>Gall biology and ecology</li>
            <li>Identification guides for common gall types</li>
            <li>Host plant relationships</li>
            <li>Life cycles of gall-forming organisms</li>
            <li>Regional gall guides</li>
            <li>Citizen science and data collection tips</li>
          </ul>
        </div>

        <div class="mt-8 text-center">
          <p class="text-gray-600">
            For now, visit
            <.link
              href="https://gallformers.org/refindex"
              target="_blank"
              rel="noreferrer"
              class="text-gf-maroon hover:underline"
            >
              the current Gallformers site
            </.link>
            to access the existing reference articles.
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
