# iNat Image Import Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add an iNaturalist observation image import flow to the Images Admin page.

**Architecture:** LiveComponent in the upload section with its own state lifecycle. New `Gallformers.INaturalist` context for API interaction. Shared `Images.finalize_upload/4` extraction so both upload paths use the same record-creation + variant-generation code.

**Tech Stack:** Phoenix LiveView, Req HTTP client, ExAws S3, Tailwind CSS v4

**Design doc:** `docs/plans/2026-02-14-inat-image-import-design.md`

**iNat API reference:** Use the `inaturalist-api` skill for all API details (endpoints, rate limits, photo URL patterns, licensing, gotchas).

---

## Task 1: Extract `Images.finalize_upload/4`

Extract the inline upload-completion logic from `ImagesLive` into a shared context function.

**Files:**
- Modify: `lib/gallformers/images.ex` (add `finalize_upload/4`)
- Modify: `lib/gallformers_web/live/admin/images_live.ex:1072-1107` (call the new function)
- Test: `test/gallformers/images_test.exs` (add tests for `finalize_upload/4`)

**Step 1: Write the failing test**

```elixir
# In test/gallformers/images_test.exs, add a new describe block

describe "finalize_upload/4" do
  test "creates image record with correct attributes" do
    species = insert_species()
    path = "gall/#{species.id}/#{species.id}_123_456_original.jpg"

    assert {:ok, image} = Images.finalize_upload(path, species.id, "testuser")
    assert image.path == path
    assert image.species_id == species.id
    assert image.uploader == "testuser"
    assert image.lastchangedby == "testuser"
  end

  test "accepts extra metadata attrs" do
    species = insert_species()
    path = "gall/#{species.id}/#{species.id}_123_456_original.jpg"

    attrs = %{
      creator: "janedoe - Jane Doe",
      license: "CC-BY-NC",
      licenselink: "https://creativecommons.org/licenses/by-nc/4.0/",
      sourcelink: "https://www.inaturalist.org/observations/12345"
    }

    assert {:ok, image} = Images.finalize_upload(path, species.id, "testuser", attrs)
    assert image.creator == "janedoe - Jane Doe"
    assert image.license == "CC-BY-NC"
    assert image.sourcelink == "https://www.inaturalist.org/observations/12345"
  end

  test "assigns next sort_order" do
    species = insert_species()
    path1 = "gall/#{species.id}/#{species.id}_1_1_original.jpg"
    path2 = "gall/#{species.id}/#{species.id}_2_2_original.jpg"

    {:ok, img1} = Images.finalize_upload(path1, species.id, "testuser")
    {:ok, img2} = Images.finalize_upload(path2, species.id, "testuser")

    assert img1.sort_order == 0
    assert img2.sort_order == 1
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/gallformers/images_test.exs --only describe:"finalize_upload/4"`
Expected: FAIL — `finalize_upload/4` is undefined

**Step 3: Implement `finalize_upload/4`**

Add to `lib/gallformers/images.ex` in the "Image CRUD Operations" section, after `create_image/1`:

```elixir
@doc """
Creates an image record and schedules background size variant generation.

Used by both the presigned-URL upload flow and the iNat import flow.
`extra_attrs` can include `:creator`, `:license`, `:licenselink`, `:sourcelink`, etc.
"""
@spec finalize_upload(String.t(), integer(), String.t(), map()) ::
        {:ok, ImageSchema.t()} | {:error, Ecto.Changeset.t()}
def finalize_upload(path, species_id, uploader, extra_attrs \\ %{}) do
  attrs =
    Map.merge(extra_attrs, %{
      species_id: species_id,
      path: path,
      uploader: uploader,
      lastchangedby: uploader
    })

  case create_image(attrs) do
    {:ok, image} ->
      schedule_size_variants(path)
      {:ok, image}

    error ->
      error
  end
end

defp schedule_size_variants(path) do
  Gallformers.Async.run(fn ->
    try do
      # Wait for CDN to propagate
      Process.sleep(5000)

      case Storage.generate_size_variants(path) do
        :ok ->
          Logger.info("Successfully generated size variants for #{path}")

        {:error, reason} ->
          Logger.error("Failed to generate size variants for #{path}: #{inspect(reason)}")
      end
    rescue
      e ->
        Logger.error(
          "Exception generating size variants for #{path}: #{Exception.format(:error, e, __STACKTRACE__)}"
        )
    end
  end)
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/gallformers/images_test.exs`
Expected: PASS

**Step 5: Update `ImagesLive` to use `finalize_upload/4`**

Replace the inline logic in `lib/gallformers_web/live/admin/images_live.ex:1077-1107` with:

```elixir
# Replace lines 1077-1107 (the Enum.each block) with:
Enum.each(paths, fn path ->
  Images.finalize_upload(path, species_id, uploader)
end)
```

The `schedule_size_variants/1` private function now lives in the Images context, so remove
the duplicated variant-generation code from the event handler.

**Step 6: Run full test suite to verify no regressions**

Run: `mix precommit`
Expected: PASS

**Step 7: Commit**

```bash
git add lib/gallformers/images.ex lib/gallformers_web/live/admin/images_live.ex test/gallformers/images_test.exs
git commit -m "Extract Images.finalize_upload/4 from uploads_completed handler"
```

---

## Task 2: `Gallformers.INaturalist` context — structs and license mapping

Create the iNat context with struct definitions and the license mapping function. No API calls
yet — just the data layer.

**Files:**
- Create: `lib/gallformers/inaturalist.ex`
- Create: `lib/gallformers/inaturalist/observation.ex`
- Create: `lib/gallformers/inaturalist/photo.ex`
- Test: `test/gallformers/inaturalist_test.exs`

**Step 1: Write the failing tests**

```elixir
# test/gallformers/inaturalist_test.exs
defmodule Gallformers.INaturalistTest do
  use ExUnit.Case, async: true

  alias Gallformers.INaturalist

  describe "map_license/1" do
    test "maps iNat license codes to Gallformers licenses" do
      assert INaturalist.map_license("cc0") == "Public Domain / CC0"
      assert INaturalist.map_license("cc-by") == "CC-BY"
      assert INaturalist.map_license("cc-by-sa") == "CC-BY-SA"
      assert INaturalist.map_license("cc-by-nc") == "CC-BY-NC"
      assert INaturalist.map_license("cc-by-nc-sa") == "CC-BY-NC-SA"
      assert INaturalist.map_license("cc-by-nd") == "CC-BY-ND"
      assert INaturalist.map_license("cc-by-nc-nd") == "CC-BY-NC-ND"
    end

    test "maps nil to All Rights Reserved" do
      assert INaturalist.map_license(nil) == "All Rights Reserved"
    end
  end

  describe "parse_observation_id/1" do
    test "extracts ID from full URL" do
      assert INaturalist.parse_observation_id("https://www.inaturalist.org/observations/12345") ==
               {:ok, "12345"}
    end

    test "extracts ID from URL without www" do
      assert INaturalist.parse_observation_id("https://inaturalist.org/observations/12345") ==
               {:ok, "12345"}
    end

    test "extracts ID from URL with query string" do
      assert INaturalist.parse_observation_id(
               "https://www.inaturalist.org/observations/12345?locale=en"
             ) == {:ok, "12345"}
    end

    test "extracts ID from URL with fragment" do
      assert INaturalist.parse_observation_id(
               "https://www.inaturalist.org/observations/12345#activity"
             ) == {:ok, "12345"}
    end

    test "accepts bare numeric ID" do
      assert INaturalist.parse_observation_id("12345") == {:ok, "12345"}
    end

    test "rejects invalid input" do
      assert INaturalist.parse_observation_id("not-a-url") == {:error, :invalid_input}
      assert INaturalist.parse_observation_id("https://example.com/123") == {:error, :invalid_input}
      assert INaturalist.parse_observation_id("") == {:error, :invalid_input}
    end
  end

  describe "format_creator/2" do
    test "formats login and name" do
      assert INaturalist.format_creator("janedoe", "Jane Doe") == "janedoe - Jane Doe"
    end

    test "uses login only when name is nil" do
      assert INaturalist.format_creator("janedoe", nil) == "janedoe"
    end

    test "uses login only when name is empty" do
      assert INaturalist.format_creator("janedoe", "") == "janedoe"
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/gallformers/inaturalist_test.exs`
Expected: FAIL — module not found

**Step 3: Create the structs**

```elixir
# lib/gallformers/inaturalist/photo.ex
defmodule Gallformers.INaturalist.Photo do
  @moduledoc """
  Represents a photo from an iNaturalist observation.
  """

  @enforce_keys [:id, :thumbnail_url, :original_url, :mapped_license]
  defstruct [:id, :thumbnail_url, :original_url, :license_code, :mapped_license, :all_rights_reserved?]

  @type t :: %__MODULE__{
          id: integer(),
          thumbnail_url: String.t(),
          original_url: String.t(),
          license_code: String.t() | nil,
          mapped_license: String.t(),
          all_rights_reserved?: boolean()
        }
end
```

```elixir
# lib/gallformers/inaturalist/observation.ex
defmodule Gallformers.INaturalist.Observation do
  @moduledoc """
  Represents a parsed iNaturalist observation with its photos.
  """

  alias Gallformers.INaturalist.Photo

  @enforce_keys [:id, :observer_login, :url, :photos]
  defstruct [:id, :taxon_name, :observer_login, :observer_name, :url, photos: []]

  @type t :: %__MODULE__{
          id: integer(),
          taxon_name: String.t() | nil,
          observer_login: String.t(),
          observer_name: String.t() | nil,
          url: String.t(),
          photos: [Photo.t()]
        }
end
```

**Step 4: Create the context module**

```elixir
# lib/gallformers/inaturalist.ex
defmodule Gallformers.INaturalist do
  @moduledoc """
  Context for interacting with the iNaturalist API.

  Handles observation fetching, photo downloading, URL parsing, and
  license mapping between iNat and Gallformers formats.
  """

  alias Gallformers.INaturalist.{Observation, Photo}

  @license_map %{
    "cc0" => "Public Domain / CC0",
    "cc-by" => "CC-BY",
    "cc-by-sa" => "CC-BY-SA",
    "cc-by-nc" => "CC-BY-NC",
    "cc-by-nc-sa" => "CC-BY-NC-SA",
    "cc-by-nd" => "CC-BY-ND",
    "cc-by-nc-nd" => "CC-BY-NC-ND"
  }

  @observation_url_pattern ~r{https?://(?:www\.)?inaturalist\.org/observations/(\d+)}

  @doc """
  Maps an iNat `license_code` to a Gallformers license string.
  Returns "All Rights Reserved" for nil (no license).
  """
  @spec map_license(String.t() | nil) :: String.t()
  def map_license(nil), do: "All Rights Reserved"
  def map_license(code), do: Map.get(@license_map, code, "All Rights Reserved")

  @doc """
  Parses an iNaturalist observation URL or bare ID into an observation ID.
  """
  @spec parse_observation_id(String.t()) :: {:ok, String.t()} | {:error, :invalid_input}
  def parse_observation_id(input) when is_binary(input) do
    input = String.trim(input)

    cond do
      input == "" ->
        {:error, :invalid_input}

      Regex.match?(~r/^\d+$/, input) ->
        {:ok, input}

      match = Regex.run(@observation_url_pattern, input) ->
        {:ok, Enum.at(match, 1)}

      true ->
        {:error, :invalid_input}
    end
  end

  @doc """
  Formats the creator field from iNat user login and display name.
  """
  @spec format_creator(String.t(), String.t() | nil) :: String.t()
  def format_creator(login, nil), do: login
  def format_creator(login, ""), do: login
  def format_creator(login, name), do: "#{login} - #{name}"
end
```

**Step 5: Run tests to verify they pass**

Run: `mix test test/gallformers/inaturalist_test.exs`
Expected: PASS

**Step 6: Run precommit**

Run: `mix precommit`
Expected: PASS

**Step 7: Commit**

```bash
git add lib/gallformers/inaturalist.ex lib/gallformers/inaturalist/ test/gallformers/inaturalist_test.exs
git commit -m "Add INaturalist context with structs and license mapping"
```

---

## Task 3: `INaturalist.fetch_observation/1` — API integration

Add the function that calls the iNat v1 API and parses the response into structs.

**Files:**
- Modify: `lib/gallformers/inaturalist.ex` (add `fetch_observation/1`, `download_photo/1`)
- Test: `test/gallformers/inaturalist_test.exs` (add tests with mocked HTTP)

**Important iNat API details** (from the `inaturalist-api` skill):
- Endpoint: `GET https://api.inaturalist.org/v1/observations/{id}`
- No auth needed for public observations
- Set `User-Agent: Gallformers/1.0 (gallformers.org)`
- Photo URLs come back with `square` size — replace with `medium` for thumbnails, `original` for download
- Two CDN hosts exist (`static.inaturalist.org` and `inaturalist-open-data.s3.amazonaws.com`) — use whichever the API returns

**Step 1: Write failing tests**

We need to mock the HTTP client. The project already uses Req. The cleanest approach:
add a `@http_client` module attribute that defaults to `Req` but can be overridden in tests
via application config. Alternatively, pass the raw JSON through a `parse_observation_response/1`
function that we test directly without HTTP mocking.

**Recommended: Test the parsing function directly**, test the HTTP integration with a real
call in a tagged test (excluded by default).

```elixir
# Add to test/gallformers/inaturalist_test.exs

describe "parse_observation_response/1" do
  test "parses a valid observation response" do
    json = %{
      "results" => [
        %{
          "id" => 12345,
          "taxon" => %{"name" => "Andricus quercuscalifornicus"},
          "user" => %{"login" => "janedoe", "name" => "Jane Doe"},
          "photos" => [
            %{
              "id" => 111,
              "url" => "https://inaturalist-open-data.s3.amazonaws.com/photos/111/square.jpg",
              "license_code" => "cc-by-nc"
            },
            %{
              "id" => 222,
              "url" => "https://static.inaturalist.org/photos/222/square.jpeg",
              "license_code" => nil
            }
          ]
        }
      ]
    }

    assert {:ok, obs} = INaturalist.parse_observation_response(json)
    assert obs.id == 12345
    assert obs.taxon_name == "Andricus quercuscalifornicus"
    assert obs.observer_login == "janedoe"
    assert obs.observer_name == "Jane Doe"
    assert obs.url == "https://www.inaturalist.org/observations/12345"
    assert length(obs.photos) == 2

    [photo1, photo2] = obs.photos
    assert photo1.id == 111
    assert photo1.thumbnail_url == "https://inaturalist-open-data.s3.amazonaws.com/photos/111/medium.jpg"
    assert photo1.original_url == "https://inaturalist-open-data.s3.amazonaws.com/photos/111/original.jpg"
    assert photo1.mapped_license == "CC-BY-NC"
    assert photo1.all_rights_reserved? == false

    assert photo2.id == 222
    assert photo2.mapped_license == "All Rights Reserved"
    assert photo2.all_rights_reserved? == true
  end

  test "returns error for empty results" do
    json = %{"results" => []}
    assert {:error, :not_found} = INaturalist.parse_observation_response(json)
  end

  test "handles observation with no photos" do
    json = %{
      "results" => [
        %{
          "id" => 99999,
          "taxon" => nil,
          "user" => %{"login" => "someone", "name" => nil},
          "photos" => []
        }
      ]
    }

    assert {:ok, obs} = INaturalist.parse_observation_response(json)
    assert obs.photos == []
    assert obs.taxon_name == nil
    assert obs.observer_name == nil
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/gallformers/inaturalist_test.exs`
Expected: FAIL — `parse_observation_response/1` undefined

**Step 3: Implement `parse_observation_response/1`, `fetch_observation/1`, and `download_photo/1`**

Add to `lib/gallformers/inaturalist.ex`:

```elixir
require Logger

@api_base "https://api.inaturalist.org/v1"
@user_agent "Gallformers/1.0 (gallformers.org)"

@doc """
Fetches an iNaturalist observation by URL or ID.
Returns `{:ok, Observation.t()}` or `{:error, reason}`.
"""
@spec fetch_observation(String.t()) :: {:ok, Observation.t()} | {:error, atom()}
def fetch_observation(input) do
  with {:ok, id} <- parse_observation_id(input),
       {:ok, json} <- do_fetch_observation(id) do
    parse_observation_response(json)
  end
end

@doc """
Downloads a photo from the given URL. Returns `{:ok, binary}` or `{:error, reason}`.
"""
@spec download_photo(String.t()) :: {:ok, binary()} | {:error, term()}
def download_photo(url) do
  case Req.get(url, headers: [{"user-agent", @user_agent}]) do
    {:ok, %{status: 200, body: body}} when is_binary(body) ->
      {:ok, body}

    {:ok, %{status: status}} ->
      {:error, {:http_error, status}}

    {:error, reason} ->
      {:error, reason}
  end
end

@doc """
Parses a raw iNat API observation response into an Observation struct.
"""
@spec parse_observation_response(map()) :: {:ok, Observation.t()} | {:error, :not_found}
def parse_observation_response(%{"results" => [raw | _]}) do
  photos =
    (raw["photos"] || [])
    |> Enum.map(fn p ->
      license_code = p["license_code"]
      mapped = map_license(license_code)

      %Photo{
        id: p["id"],
        thumbnail_url: photo_size_url(p["url"], "medium"),
        original_url: photo_size_url(p["url"], "original"),
        license_code: license_code,
        mapped_license: mapped,
        all_rights_reserved?: license_code == nil
      }
    end)

  obs = %Observation{
    id: raw["id"],
    taxon_name: get_in(raw, ["taxon", "name"]),
    observer_login: get_in(raw, ["user", "login"]),
    observer_name: get_in(raw, ["user", "name"]),
    url: "https://www.inaturalist.org/observations/#{raw["id"]}",
    photos: photos
  }

  {:ok, obs}
end

def parse_observation_response(%{"results" => []}), do: {:error, :not_found}
def parse_observation_response(_), do: {:error, :invalid_response}

# Replace "square" (or any size) in a photo URL with the requested size.
defp photo_size_url(url, size) when is_binary(url) do
  String.replace(url, ~r{/square\.(jpe?g|png)}, "/#{size}.\\1")
end

defp do_fetch_observation(id) do
  url = "#{@api_base}/observations/#{id}"

  case Req.get(url, headers: [{"user-agent", @user_agent}]) do
    {:ok, %{status: 200, body: body}} when is_map(body) ->
      {:ok, body}

    {:ok, %{status: 404}} ->
      {:error, :not_found}

    {:ok, %{status: status}} ->
      Logger.warning("iNat API returned status #{status} for observation #{id}")
      {:error, {:http_error, status}}

    {:error, reason} ->
      Logger.error("iNat API request failed for observation #{id}: #{inspect(reason)}")
      {:error, reason}
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `mix test test/gallformers/inaturalist_test.exs`
Expected: PASS

**Step 5: Run precommit**

Run: `mix precommit`
Expected: PASS

**Step 6: Commit**

```bash
git add lib/gallformers/inaturalist.ex test/gallformers/inaturalist_test.exs
git commit -m "Add iNat observation fetching and response parsing"
```

---

## Task 4: `InatImportComponent` — idle and fetching states

Build the LiveComponent with the first two states. This gets the UI visible and the API call wired up.

**Files:**
- Create: `lib/gallformers_web/live/admin/inat_import_component.ex`
- Modify: `lib/gallformers_web/live/admin/images_live.ex` (mount component in template)
- Test: `test/gallformers_web/live/admin/inat_import_component_test.exs`

**Step 1: Write failing test**

```elixir
# test/gallformers_web/live/admin/inat_import_component_test.exs
defmodule GallformersWeb.Admin.InatImportComponentTest do
  use GallformersWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  # We test the component via the parent ImagesLive since LiveComponents
  # need a parent. Requires a species to be selected first.

  describe "inat import component" do
    setup %{conn: conn} do
      species = insert_species()
      conn = init_test_session(conn, %{"current_user" => "test@test.com"})
      {:ok, view, _html} = live(conn, ~p"/admin/images")

      # Select the species to show the upload section
      view
      |> element("[data-role=species-typeahead-result]", species.name)
      |> render_click()

      %{view: view, species: species}
    end

    test "renders idle state with input field", %{view: view} do
      html = render(view)
      assert html =~ "iNaturalist"
      assert html =~ "observation"
      assert has_element?(view, "[data-role=inat-url-input]")
      assert has_element?(view, "[data-role=inat-fetch-button][disabled]")
    end
  end
end
```

**NOTE:** The exact test setup depends on how the ImagesLive species search works. The
implementer should check the existing test patterns and adjust the setup accordingly. The
important thing is testing that the component renders in the upload section.

**Step 2: Run test to verify it fails**

Run: `mix test test/gallformers_web/live/admin/inat_import_component_test.exs`
Expected: FAIL — component doesn't exist

**Step 3: Create the LiveComponent**

```elixir
# lib/gallformers_web/live/admin/inat_import_component.ex
defmodule GallformersWeb.Admin.InatImportComponent do
  @moduledoc """
  LiveComponent for importing images from iNaturalist observations.

  Mounted in the Images Admin upload section. Owns its own lifecycle:
  :idle → :fetching → :picking → :importing → :done
  """

  use GallformersWeb, :live_component

  alias Gallformers.INaturalist

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:state, :idle)
     |> assign(:url_input, "")
     |> assign(:error, nil)
     |> assign(:observation, nil)
     |> assign(:selected_photo_ids, MapSet.new())
     |> assign(:import_progress, nil)}
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(:species_id, assigns.species_id)
     |> assign(:uploader, assigns.uploader)
     |> assign(:id, assigns.id)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mt-6 border-t border-gray-200 pt-6">
      <h3 class="text-sm font-medium text-gray-700 mb-3">Import from iNaturalist</h3>

      <div :if={@state == :idle} class="flex gap-2">
        <input
          type="text"
          data-role="inat-url-input"
          value={@url_input}
          placeholder="iNaturalist observation URL or ID"
          phx-keyup="inat_url_changed"
          phx-key="Enter"
          phx-target={@myself}
          class="flex-1 rounded-md border-gray-300 shadow-sm focus:border-gf-maroon focus:ring-gf-maroon text-sm"
        />
        <button
          data-role="inat-fetch-button"
          phx-click="inat_fetch"
          phx-target={@myself}
          disabled={@url_input == ""}
          class="px-4 py-2 bg-gf-maroon text-white rounded-md hover:bg-gf-maroon/90 disabled:opacity-50 disabled:cursor-not-allowed text-sm"
        >
          Fetch
        </button>
      </div>

      <div :if={@state == :fetching} class="flex items-center gap-3">
        <.loading_spinner size="sm" />
        <span class="text-sm text-gray-600">Fetching observation...</span>
        <button
          phx-click="inat_cancel"
          phx-target={@myself}
          class="text-sm text-gray-500 hover:text-gray-700"
        >
          Cancel
        </button>
      </div>

      <.error_message :if={@error} message={@error} />
    </div>
    """
  end

  @impl true
  def handle_event("inat_url_changed", %{"value" => value}, socket) do
    {:noreply, assign(socket, :url_input, value)}
  end

  def handle_event("inat_url_changed", %{"key" => "Enter"}, socket) do
    if socket.assigns.url_input != "" do
      handle_event("inat_fetch", %{}, socket)
    else
      {:noreply, socket}
    end
  end

  def handle_event("inat_fetch", _params, socket) do
    input = socket.assigns.url_input

    case INaturalist.parse_observation_id(input) do
      {:ok, _id} ->
        # Start async fetch
        socket = assign(socket, state: :fetching, error: nil)
        send_update_after(__MODULE__, [id: socket.assigns.id, fetch_input: input], 0)
        {:noreply, socket}

      {:error, :invalid_input} ->
        {:noreply, assign(socket, :error, "Please enter a valid iNaturalist observation URL or numeric ID.")}
    end
  end

  def handle_event("inat_cancel", _params, socket) do
    {:noreply, assign(socket, state: :idle, error: nil)}
  end
end
```

**NOTE on the input event:** The `phx-keyup` binding needs refinement. The implementer should
check how other inputs work in the codebase (e.g., the species search typeahead) and match the
pattern. The key behavior needed: update `url_input` on every keystroke, and trigger fetch on
Enter. A `phx-change` on a wrapping form may be cleaner.

**Step 4: Mount the component in ImagesLive**

In `lib/gallformers_web/live/admin/images_live.ex`, inside the upload section (after line 549,
before the closing `</div>` of the upload section):

```heex
<.live_component
  module={GallformersWeb.Admin.InatImportComponent}
  id="inat-import"
  species_id={@selected_species.id}
  uploader={@db_display_name}
/>
```

Add the alias at the top of the module (near line 21):

```elixir
alias GallformersWeb.Admin.InatImportComponent
```

**Step 5: Run test to verify it passes**

Run: `mix test test/gallformers_web/live/admin/inat_import_component_test.exs`
Expected: PASS

**Step 6: Run precommit**

Run: `mix precommit`
Expected: PASS

**Step 7: Commit**

```bash
git add lib/gallformers_web/live/admin/inat_import_component.ex lib/gallformers_web/live/admin/images_live.ex test/gallformers_web/live/admin/inat_import_component_test.exs
git commit -m "Add InatImportComponent with idle and fetching states"
```

---

## Task 5: `InatImportComponent` — picking state (photo grid)

Wire up the async fetch result and render the thumbnail grid with checkboxes.

**Files:**
- Modify: `lib/gallformers_web/live/admin/inat_import_component.ex`
- Test: `test/gallformers_web/live/admin/inat_import_component_test.exs`

**Step 1: Write failing test**

```elixir
# Add to the existing test file's describe block

test "shows photo picker after successful fetch", %{view: view} do
  # This test depends on being able to simulate a successful fetch.
  # The implementer should either:
  # 1. Use a test helper that injects a mock observation into the component
  # 2. Or test via the parse_observation_response path with a fixture

  # The key assertions for the picking state:
  html = render(view)
  assert html =~ "Import Selected"
  assert has_element?(view, "[data-role=inat-photo-grid]")
  assert has_element?(view, "[data-role=inat-photo-checkbox]")
end
```

**NOTE:** Testing async LiveComponent state transitions with real HTTP calls is tricky.
The implementer should decide whether to:
- Use `Req.Test` (Req's built-in test adapter) to stub the HTTP response
- Or test the component states more directly via unit tests of the rendering functions

The design doc's response parsing is already well-tested in Task 3. The component test
focus should be on: "given an observation struct, does the picking UI render correctly?"

**Step 2: Implement the picking state**

Add to `update/2` in the component to handle the async fetch result:

```elixir
# In update/2, add a clause for the fetch result
def update(%{fetch_input: input} = assigns, socket) do
  case INaturalist.fetch_observation(input) do
    {:ok, observation} ->
      {:ok,
       socket
       |> assign(:state, :picking)
       |> assign(:observation, observation)
       |> assign(:selected_photo_ids, MapSet.new())
       |> assign(:error, nil)}

    {:error, :not_found} ->
      {:ok, assign(socket, state: :idle, error: "Observation not found.")}

    {:error, _reason} ->
      {:ok, assign(socket, state: :idle, error: "Failed to fetch observation. Please try again.")}
  end
end
```

Add the picking state to `render/1`:

```heex
<div :if={@state == :picking}>
  <%!-- Observation header --%>
  <div class="mb-4 text-sm text-gray-600">
    <p>
      <span :if={@observation.taxon_name} class="font-medium italic">
        {@observation.taxon_name}
      </span>
      observed by
      <span class="font-medium">{INaturalist.format_creator(@observation.observer_login, @observation.observer_name)}</span>
      — <a href={@observation.url} target="_blank" class="text-gf-maroon hover:underline">
        view on iNaturalist
      </a>
    </p>
  </div>

  <%!-- Photo grid --%>
  <div :if={@observation.photos == []} class="text-sm text-gray-500 py-4">
    This observation has no photos.
  </div>

  <div :if={@observation.photos != []} data-role="inat-photo-grid" class="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-5 gap-3 mb-4">
    <label
      :for={photo <- @observation.photos}
      class={[
        "relative cursor-pointer rounded-lg overflow-hidden border-2 transition-colors",
        if(MapSet.member?(@selected_photo_ids, photo.id),
          do: "border-gf-maroon",
          else: "border-gray-200 hover:border-gray-300"
        )
      ]}
    >
      <img
        src={photo.thumbnail_url}
        class="w-full aspect-square object-cover"
        loading="lazy"
      />
      <input
        type="checkbox"
        data-role="inat-photo-checkbox"
        checked={MapSet.member?(@selected_photo_ids, photo.id)}
        phx-click="inat_toggle_photo"
        phx-value-photo-id={photo.id}
        phx-target={@myself}
        class="absolute top-2 left-2 h-4 w-4 rounded border-gray-300 text-gf-maroon focus:ring-gf-maroon"
      />
      <div
        :if={photo.all_rights_reserved?}
        class="absolute bottom-0 inset-x-0 bg-amber-500/90 text-white text-xs px-2 py-1 text-center"
      >
        All Rights Reserved
      </div>
      <div class="absolute bottom-0 inset-x-0 bg-black/50 text-white text-xs px-2 py-1 text-center"
        :if={!photo.all_rights_reserved?}
      >
        {photo.mapped_license}
      </div>
    </label>
  </div>

  <%!-- Action buttons --%>
  <div class="flex gap-2">
    <button
      phx-click="inat_import"
      phx-target={@myself}
      disabled={MapSet.size(@selected_photo_ids) == 0}
      class="px-4 py-2 bg-gf-maroon text-white rounded-md hover:bg-gf-maroon/90 disabled:opacity-50 disabled:cursor-not-allowed text-sm"
    >
      Import Selected ({MapSet.size(@selected_photo_ids)})
    </button>
    <button
      phx-click="inat_cancel"
      phx-target={@myself}
      class="px-4 py-2 text-gray-600 hover:text-gray-800 text-sm"
    >
      Cancel
    </button>
  </div>
</div>
```

Add the toggle event handler:

```elixir
def handle_event("inat_toggle_photo", %{"photo-id" => photo_id_str}, socket) do
  photo_id = String.to_integer(photo_id_str)

  selected =
    if MapSet.member?(socket.assigns.selected_photo_ids, photo_id) do
      MapSet.delete(socket.assigns.selected_photo_ids, photo_id)
    else
      MapSet.put(socket.assigns.selected_photo_ids, photo_id)
    end

  {:noreply, assign(socket, :selected_photo_ids, selected)}
end
```

**Step 3: Run tests**

Run: `mix test test/gallformers_web/live/admin/inat_import_component_test.exs`
Expected: PASS

**Step 4: Run precommit**

Run: `mix precommit`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/gallformers_web/live/admin/inat_import_component.ex test/gallformers_web/live/admin/inat_import_component_test.exs
git commit -m "Add photo picker grid to InatImportComponent"
```

---

## Task 6: `InatImportComponent` — importing and done states

Wire up the actual import: download from iNat, upload to S3, create records.

**Files:**
- Modify: `lib/gallformers_web/live/admin/inat_import_component.ex`
- Test: `test/gallformers_web/live/admin/inat_import_component_test.exs`

**Step 1: Implement the import handler**

```elixir
def handle_event("inat_import", _params, socket) do
  selected_ids = socket.assigns.selected_photo_ids
  photos = Enum.filter(socket.assigns.observation.photos, &MapSet.member?(selected_ids, &1.id))
  total = length(photos)

  socket = assign(socket, state: :importing, import_progress: %{current: 0, total: total, errors: []})

  # Process photos sequentially via send_update_after
  send_update_after(__MODULE__, [id: socket.assigns.id, import_photos: photos, import_index: 0], 0)

  {:noreply, socket}
end
```

Add to `update/2`:

```elixir
def update(%{import_photos: photos, import_index: index} = _assigns, socket) do
  if index >= length(photos) do
    # All done
    errors = socket.assigns.import_progress.errors
    imported = socket.assigns.import_progress.total - length(errors)

    message =
      case {imported, length(errors)} do
        {n, 0} -> "Imported #{n} image(s) successfully."
        {0, e} -> "Failed to import #{e} image(s)."
        {n, e} -> "Imported #{n} image(s). #{e} failed."
      end

    # Notify parent to refresh images
    send(self(), {:inat_import_complete, socket.assigns.species_id})

    {:ok,
     socket
     |> assign(:state, :done)
     |> assign(:error, if(length(errors) > 0, do: Enum.join(errors, "; ")))
     |> assign(:done_message, message)}
  else
    photo = Enum.at(photos, index)
    progress = %{socket.assigns.import_progress | current: index + 1}
    socket = assign(socket, :import_progress, progress)

    case import_single_photo(photo, socket.assigns) do
      :ok ->
        :ok

      {:error, reason} ->
        errors = progress.errors ++ ["Photo #{photo.id}: #{inspect(reason)}"]
        socket = put_in(socket.assigns.import_progress.errors, errors)
    end

    # Schedule next photo with delay to respect iNat rate limits
    send_update_after(__MODULE__, [id: socket.assigns.id, import_photos: photos, import_index: index + 1], 1_000)

    {:ok, socket}
  end
end

defp import_single_photo(photo, assigns) do
  with {:ok, binary} <- INaturalist.download_photo(photo.original_url),
       path <- Storage.generate_path(assigns.species_id, extension_from_url(photo.original_url)),
       {:ok, _} <- Storage.upload(path, binary, content_type_from_url(photo.original_url)),
       obs <- assigns.observation,
       creator <- INaturalist.format_creator(obs.observer_login, obs.observer_name),
       {:ok, _image} <-
         Images.finalize_upload(path, assigns.species_id, assigns.uploader, %{
           creator: creator,
           license: photo.mapped_license,
           licenselink: Licenses.url(photo.mapped_license),
           sourcelink: obs.url
         }) do
    :ok
  else
    {:error, reason} -> {:error, reason}
  end
end

defp extension_from_url(url) do
  url
  |> URI.parse()
  |> Map.get(:path, "")
  |> Path.extname()
  |> String.trim_leading(".")
  |> case do
    "" -> "jpg"
    ext -> ext
  end
end

defp content_type_from_url(url) do
  case extension_from_url(url) do
    "png" -> "image/png"
    _ -> "image/jpeg"
  end
end
```

Add the importing and done states to `render/1`:

```heex
<div :if={@state == :importing} class="flex items-center gap-3">
  <.loading_spinner size="sm" />
  <span class="text-sm text-gray-600">
    Importing {@import_progress.current} of {@import_progress.total}...
  </span>
</div>

<div :if={@state == :done} class="text-sm">
  <p class="text-green-700 font-medium">{@done_message}</p>
  <button
    phx-click="inat_reset"
    phx-target={@myself}
    class="mt-2 text-sm text-gf-maroon hover:underline"
  >
    Import another
  </button>
</div>
```

Add the reset handler:

```elixir
def handle_event("inat_reset", _params, socket) do
  {:noreply,
   socket
   |> assign(:state, :idle)
   |> assign(:url_input, "")
   |> assign(:error, nil)
   |> assign(:observation, nil)
   |> assign(:selected_photo_ids, MapSet.new())
   |> assign(:import_progress, nil)
   |> assign(:done_message, nil)}
end
```

**Step 2: Handle `inat_import_complete` in the parent LiveView**

Add to `lib/gallformers_web/live/admin/images_live.ex`:

```elixir
@impl true
def handle_info({:inat_import_complete, species_id}, socket) do
  images = Images.list_images_for_species(species_id)

  {:noreply,
   socket
   |> assign(:images, images)
   |> update(:images_version, &(&1 + 1))}
end
```

**Step 3: Run tests**

Run: `mix test test/gallformers_web/live/admin/inat_import_component_test.exs`
Expected: PASS

**Step 4: Run precommit**

Run: `mix precommit`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/gallformers_web/live/admin/inat_import_component.ex lib/gallformers_web/live/admin/images_live.ex test/gallformers_web/live/admin/inat_import_component_test.exs
git commit -m "Add import and done states to InatImportComponent"
```

---

## Task 7: Manual testing and polish

Smoke-test the full flow end-to-end with a real iNat observation.

**Step 1: Start the dev server**

Run: `mix phx.server`

**Step 2: Test the happy path**

1. Go to `/admin/images`
2. Search for and select a species
3. Paste a known iNat observation URL (e.g., `https://www.inaturalist.org/observations/1234`)
4. Click Fetch — verify observation info appears
5. Check some photos, click Import Selected
6. Verify images appear in the grid with correct metadata
7. Click an imported image's edit button — verify creator, license, sourcelink are populated

**Step 3: Test edge cases**

- Invalid URL → error message
- Non-existent observation ID → "not found" error
- Observation with no photos → "no photos" message
- Observation with ARR photos → warning badge visible
- Import with ARR photo selected → works, shows "All Rights Reserved" license

**Step 4: Fix any issues found**

Address UI polish, spacing, error messages, etc.

**Step 5: Run precommit**

Run: `mix precommit`
Expected: PASS

**Step 6: Commit any fixes**

```bash
git add -p  # Stage specific fixes
git commit -m "Polish iNat import UI after manual testing"
```

---

## Notes for the implementer

**iNat API reference:** Invoke the `inaturalist-api` skill for details on endpoints, photo URL
patterns, rate limits, and licensing. Key points:
- Photo URLs use `square` by default — replace with `medium`/`original` via string replacement
- No auth needed for public reads
- Rate limit: stay under 60 req/min, ~1s between requests
- `license_code: null` = All Rights Reserved

**Existing patterns to follow:**
- Species search typeahead: see `ImagesLive` lines 24-45 for assign patterns
- Modal rendering: see `ImagesLive` line 554+ for `.modal` usage
- Error messages: use `<.error_message>` from `ui_components.ex`
- Loading spinners: use `<.loading_spinner>` from `ui_components.ex`

**S3 isolation in tests:** Use `Gallformers.S3.request/1` not `ExAws.request/1`. The test
environment has `s3_enabled: false` which returns mock success.

**Don't forget:**
- `mix precommit` after every task
- The `update/2` function in LiveComponent needs careful ordering — the initial `update` from
  parent assigns vs. the `send_update_after` updates must not clobber each other
