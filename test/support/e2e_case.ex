defmodule GallformersWeb.E2ECase do
  @moduledoc """
  Test case for E2E browser tests using Wallaby.

  These tests run in a real browser (Chrome) and exercise the full application stack.
  They are excluded from regular `mix test` runs and must be explicitly enabled.

  ## Prerequisites

  Install ChromeDriver (required by Wallaby):

      # macOS
      brew install chromedriver

      # Or download from https://chromedriver.chromium.org/downloads

  ## Running E2E Tests

      # Run all E2E tests
      make e2e

      # Run specific area
      make e2e-public   # Public pages
      make e2e-admin    # Admin pages
      make e2e-search   # Search functionality
      make e2e-browse   # Species/hosts/galls browsing

      # Run with visible browser (for debugging)
      E2E_HEADED=1 make e2e

  ## Writing E2E Tests

  All E2E tests must be tagged with `@tag :e2e` plus an area tag:

      defmodule GallformersWeb.E2E.PublicTest do
        use GallformersWeb.E2ECase

        @moduletag :e2e
        @moduletag :e2e_public

        test "home page loads", %{session: session} do
          session
          |> visit("/")
          |> assert_has(Query.css("body.phx-connected"))
          |> assert_has(Query.css("h1", text: "Welcome"))
        end
      end

  Available area tags:
  - `:e2e_public` - Public browsing pages (home, about, glossary, etc.)
  - `:e2e_search` - Search and ID tool
  - `:e2e_browse` - Species, hosts, galls browsing
  - `:e2e_admin` - Admin dashboard and CRUD
  - `:e2e_auth` - Authentication flows
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use Wallaby.Feature

      alias Wallaby.Query

      # Only import non-conflicting functions from Query
      # Use Query.text/1 explicitly when needed to avoid conflicts with Wallaby.Browser.text/1
      import Wallaby.Query, only: [css: 1, css: 2, button: 1, link: 1, fillable_field: 1]

      @endpoint GallformersWeb.Endpoint
    end
  end

  setup tags do
    # Set up database sandbox with shared mode for browser tests
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Gallformers.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Gallformers.Repo, {:shared, self()})
    end

    # Allow Wallaby's browser process to access the database
    metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(Gallformers.Repo, self())
    {:ok, session} = Wallaby.start_session(metadata: metadata)

    {:ok, session: session}
  end
end
