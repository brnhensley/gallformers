# Analytics Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add privacy-respecting page view analytics built directly into Phoenix.

**Architecture:** A `page_views` table stores anonymized visit data. A Plug tracks HTTP requests, an on_mount hook tracks LiveView navigations. An admin LiveView displays stats.

**Tech Stack:** Elixir/Phoenix, Ecto/SQLite, `browser` hex package for UA parsing.

---

## Task 1: Add browser dependency

**Files:**
- Modify: `mix.exs`

**Step 1: Add the browser dependency**

In `mix.exs`, add to the deps list:

```elixir
{:browser, "~> 0.5.5"},
```

**Step 2: Fetch dependencies**

Run: `mix deps.get`
Expected: Browser package downloaded

**Step 3: Commit**

```bash
git add mix.exs mix.lock
git commit -m "Add browser package for user agent parsing"
```

---

## Task 2: Create migration and schema

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_create_page_views.exs`
- Create: `lib/gallformers/analytics/page_view.ex`

**Step 1: Create the migration**

Run: `mix ecto.gen.migration create_page_views`

Then edit the generated file:

```elixir
defmodule Gallformers.Repo.Migrations.CreatePageViews do
  use Ecto.Migration

  def change do
    create table(:page_views) do
      add :path, :string, null: false
      add :referrer_host, :string
      add :browser, :string
      add :device_type, :string
      add :visitor_hash, :string, null: false

      timestamps(updated_at: false)
    end

    create index(:page_views, [:inserted_at])
    create index(:page_views, [:path])
    create index(:page_views, [:visitor_hash, :inserted_at])
  end
end
```

**Step 2: Create the schema**

Create `lib/gallformers/analytics/page_view.ex`:

```elixir
defmodule Gallformers.Analytics.PageView do
  @moduledoc """
  Schema for page view analytics.

  Stores anonymized page view data for traffic analysis.
  No personally identifiable information is stored.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "page_views" do
    field :path, :string
    field :referrer_host, :string
    field :browser, :string
    field :device_type, :string
    field :visitor_hash, :string

    timestamps(updated_at: false)
  end

  @required_fields [:path, :visitor_hash]
  @optional_fields [:referrer_host, :browser, :device_type]

  @doc false
  def changeset(page_view, attrs) do
    page_view
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end
end
```

**Step 3: Run migration**

Run: `mix ecto.migrate`
Expected: Migration runs successfully

**Step 4: Commit**

```bash
git add priv/repo/migrations/*_create_page_views.exs lib/gallformers/analytics/
git commit -m "Add page_views table and schema"
```

---

## Task 3: Create Analytics context module

**Files:**
- Create: `lib/gallformers/analytics.ex`

**Step 1: Create the context with tracking and query functions**

Create `lib/gallformers/analytics.ex`:

```elixir
defmodule Gallformers.Analytics do
  @moduledoc """
  The Analytics context.

  Provides privacy-respecting page view tracking and reporting.
  No personally identifiable information is stored - visitor uniqueness
  is determined by a daily hash that cannot be reversed.
  """

  import Ecto.Query

  alias Gallformers.Analytics.PageView
  alias Gallformers.Repo

  # Paths to exclude from tracking
  @excluded_path_prefixes ["/admin", "/api", "/assets", "/images", "/dev", "/health", "/auth"]
  @excluded_paths ["/favicon.ico", "/robots.txt", "/sitemap.xml"]

  # Bot user agent patterns (case-insensitive)
  @bot_patterns ~w(bot spider crawl slurp feedfetcher facebookexternalhit twitterbot linkedinbot)

  @doc """
  Records a page view asynchronously.

  Takes connection info and spawns a task to insert the record,
  ensuring page loads are never slowed by analytics.
  """
  @spec track_page_view(map()) :: :ok
  def track_page_view(attrs) do
    Task.start(fn ->
      %PageView{}
      |> PageView.changeset(attrs)
      |> Repo.insert()
    end)

    :ok
  end

  @doc """
  Determines if a request should be tracked.

  Returns false for:
  - Excluded paths (admin, api, assets, etc.)
  - Known bot user agents
  """
  @spec should_track?(String.t(), String.t() | nil) :: boolean()
  def should_track?(path, user_agent) do
    not excluded_path?(path) and not bot?(user_agent)
  end

  defp excluded_path?(path) do
    path in @excluded_paths or
      Enum.any?(@excluded_path_prefixes, &String.starts_with?(path, &1))
  end

  defp bot?(nil), do: false

  defp bot?(user_agent) do
    ua_lower = String.downcase(user_agent)
    Enum.any?(@bot_patterns, &String.contains?(ua_lower, &1))
  end

  @doc """
  Generates a daily visitor hash from IP and user agent.

  This allows counting unique visitors without storing identifiable data.
  The hash changes daily, preventing cross-day tracking.
  """
  @spec generate_visitor_hash(String.t(), String.t() | nil) :: String.t()
  def generate_visitor_hash(ip, user_agent) do
    date = Date.utc_today() |> Date.to_iso8601()
    data = "#{date}|#{ip}|#{user_agent || ""}"
    :crypto.hash(:sha256, data) |> Base.encode16(case: :lower) |> binary_part(0, 16)
  end

  @doc """
  Extracts the host from a referrer URL.

  Returns nil for empty referrers or same-site referrers.
  """
  @spec extract_referrer_host(String.t() | nil, String.t()) :: String.t() | nil
  def extract_referrer_host(nil, _site_host), do: nil
  def extract_referrer_host("", _site_host), do: nil

  def extract_referrer_host(referrer, site_host) do
    case URI.parse(referrer) do
      %URI{host: nil} -> nil
      %URI{host: host} when host == site_host -> nil
      %URI{host: host} -> host
    end
  end

  @doc """
  Parses user agent into browser family and device type.
  """
  @spec parse_user_agent(String.t() | nil) :: {String.t() | nil, String.t() | nil}
  def parse_user_agent(nil), do: {nil, nil}

  def parse_user_agent(user_agent) do
    browser = Browser.detect(user_agent)

    browser_name =
      cond do
        Browser.chrome?(browser) -> "Chrome"
        Browser.firefox?(browser) -> "Firefox"
        Browser.safari?(browser) -> "Safari"
        Browser.edge?(browser) -> "Edge"
        Browser.opera?(browser) -> "Opera"
        Browser.ie?(browser) -> "IE"
        true -> "Other"
      end

    device_type =
      cond do
        Browser.mobile?(browser) -> "mobile"
        Browser.tablet?(browser) -> "tablet"
        true -> "desktop"
      end

    {browser_name, device_type}
  end

  # =================================================================
  # Query Functions
  # =================================================================

  @doc """
  Returns page view stats for a date range.
  """
  @spec stats(Date.t(), Date.t()) :: map()
  def stats(from_date, to_date) do
    from_datetime = DateTime.new!(from_date, ~T[00:00:00], "Etc/UTC")
    to_datetime = DateTime.new!(to_date, ~T[23:59:59], "Etc/UTC")

    query =
      from(pv in PageView,
        where: pv.inserted_at >= ^from_datetime and pv.inserted_at <= ^to_datetime,
        select: %{
          page_views: count(pv.id),
          unique_visitors: count(pv.visitor_hash, :distinct)
        }
      )

    Repo.one(query) || %{page_views: 0, unique_visitors: 0}
  end

  @doc """
  Returns top pages for a date range.
  """
  @spec top_pages(Date.t(), Date.t(), integer()) :: [map()]
  def top_pages(from_date, to_date, limit \\ 20) do
    from_datetime = DateTime.new!(from_date, ~T[00:00:00], "Etc/UTC")
    to_datetime = DateTime.new!(to_date, ~T[23:59:59], "Etc/UTC")

    from(pv in PageView,
      where: pv.inserted_at >= ^from_datetime and pv.inserted_at <= ^to_datetime,
      group_by: pv.path,
      select: %{
        path: pv.path,
        views: count(pv.id),
        unique_visitors: count(pv.visitor_hash, :distinct)
      },
      order_by: [desc: count(pv.id)],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Returns top referrers for a date range.
  """
  @spec top_referrers(Date.t(), Date.t(), integer()) :: [map()]
  def top_referrers(from_date, to_date, limit \\ 20) do
    from_datetime = DateTime.new!(from_date, ~T[00:00:00], "Etc/UTC")
    to_datetime = DateTime.new!(to_date, ~T[23:59:59], "Etc/UTC")

    from(pv in PageView,
      where: pv.inserted_at >= ^from_datetime and pv.inserted_at <= ^to_datetime,
      group_by: pv.referrer_host,
      select: %{
        referrer: pv.referrer_host,
        views: count(pv.id)
      },
      order_by: [desc: count(pv.id)],
      limit: ^limit
    )
    |> Repo.all()
    |> Enum.map(fn row ->
      %{row | referrer: row.referrer || "Direct"}
    end)
  end

  @doc """
  Returns device type breakdown for a date range.
  """
  @spec device_breakdown(Date.t(), Date.t()) :: [map()]
  def device_breakdown(from_date, to_date) do
    from_datetime = DateTime.new!(from_date, ~T[00:00:00], "Etc/UTC")
    to_datetime = DateTime.new!(to_date, ~T[23:59:59], "Etc/UTC")

    from(pv in PageView,
      where: pv.inserted_at >= ^from_datetime and pv.inserted_at <= ^to_datetime,
      group_by: pv.device_type,
      select: %{
        device_type: pv.device_type,
        count: count(pv.id)
      },
      order_by: [desc: count(pv.id)]
    )
    |> Repo.all()
    |> Enum.map(fn row ->
      %{row | device_type: row.device_type || "Unknown"}
    end)
  end

  @doc """
  Returns browser breakdown for a date range.
  """
  @spec browser_breakdown(Date.t(), Date.t()) :: [map()]
  def browser_breakdown(from_date, to_date) do
    from_datetime = DateTime.new!(from_date, ~T[00:00:00], "Etc/UTC")
    to_datetime = DateTime.new!(to_date, ~T[23:59:59], "Etc/UTC")

    from(pv in PageView,
      where: pv.inserted_at >= ^from_datetime and pv.inserted_at <= ^to_datetime,
      group_by: pv.browser,
      select: %{
        browser: pv.browser,
        count: count(pv.id)
      },
      order_by: [desc: count(pv.id)]
    )
    |> Repo.all()
    |> Enum.map(fn row ->
      %{row | browser: row.browser || "Unknown"}
    end)
  end
end
```

**Step 2: Run tests to verify it compiles**

Run: `mix compile --warnings-as-errors`
Expected: Compiles without warnings

**Step 3: Commit**

```bash
git add lib/gallformers/analytics.ex
git commit -m "Add Analytics context with tracking and query functions"
```

---

## Task 4: Create the tracking Plug

**Files:**
- Create: `lib/gallformers_web/plugs/analytics.ex`

**Step 1: Create the Plug**

Create `lib/gallformers_web/plugs/analytics.ex`:

```elixir
defmodule GallformersWeb.Plugs.Analytics do
  @moduledoc """
  Plug that tracks page views for analytics.

  Runs after the response is sent and spawns an async task to record
  the page view, ensuring no impact on response time.
  """

  import Plug.Conn

  alias Gallformers.Analytics

  def init(opts), do: opts

  def call(conn, _opts) do
    register_before_send(conn, fn conn ->
      if conn.status == 200 and Analytics.should_track?(conn.request_path, user_agent(conn)) do
        track(conn)
      end

      conn
    end)
  end

  defp track(conn) do
    ip = get_client_ip(conn)
    user_agent = user_agent(conn)
    {browser, device_type} = Analytics.parse_user_agent(user_agent)

    attrs = %{
      path: conn.request_path,
      referrer_host: Analytics.extract_referrer_host(referrer(conn), conn.host),
      browser: browser,
      device_type: device_type,
      visitor_hash: Analytics.generate_visitor_hash(ip, user_agent)
    }

    Analytics.track_page_view(attrs)
  end

  defp user_agent(conn) do
    case get_req_header(conn, "user-agent") do
      [ua | _] -> ua
      [] -> nil
    end
  end

  defp referrer(conn) do
    case get_req_header(conn, "referer") do
      [ref | _] -> ref
      [] -> nil
    end
  end

  defp get_client_ip(conn) do
    # Check for forwarded IP (from Fly.io proxy)
    case get_req_header(conn, "fly-client-ip") do
      [ip | _] ->
        ip

      [] ->
        case get_req_header(conn, "x-forwarded-for") do
          [ips | _] -> ips |> String.split(",") |> List.first() |> String.trim()
          [] -> conn.remote_ip |> :inet.ntoa() |> to_string()
        end
    end
  end
end
```

**Step 2: Verify it compiles**

Run: `mix compile --warnings-as-errors`
Expected: Compiles without warnings

**Step 3: Commit**

```bash
git add lib/gallformers_web/plugs/analytics.ex
git commit -m "Add Analytics plug for HTTP request tracking"
```

---

## Task 5: Create the LiveView on_mount hook

**Files:**
- Create: `lib/gallformers_web/analytics/track_page_view.ex`

**Step 1: Create the on_mount hook**

Create `lib/gallformers_web/analytics/track_page_view.ex`:

```elixir
defmodule GallformersWeb.Analytics.TrackPageView do
  @moduledoc """
  LiveView on_mount hook for tracking page views.

  Tracks page views for LiveView navigations that happen over WebSocket
  (which bypass the HTTP Plug).
  """

  import Phoenix.LiveView
  import Phoenix.Component

  alias Gallformers.Analytics

  def on_mount(:default, _params, _session, socket) do
    if connected?(socket) do
      attach_hook(socket, :track_page_view, :handle_params, &track_navigation/3)
    end

    {:cont, socket}
  end

  defp track_navigation(_params, uri, socket) do
    %URI{path: path} = URI.parse(uri)

    # Get tracking data from socket assigns (set by initial HTTP request)
    # For LiveView navigations, we reuse the visitor hash from the session
    if Analytics.should_track?(path, nil) do
      visitor_hash = get_visitor_hash(socket)

      attrs = %{
        path: path,
        referrer_host: nil,
        browser: socket.assigns[:analytics_browser],
        device_type: socket.assigns[:analytics_device_type],
        visitor_hash: visitor_hash
      }

      Analytics.track_page_view(attrs)
    end

    {:cont, socket}
  end

  defp get_visitor_hash(socket) do
    # Use stored hash from initial page load, or generate a fallback
    socket.assigns[:analytics_visitor_hash] ||
      Analytics.generate_visitor_hash("unknown", nil)
  end
end
```

**Step 2: Verify it compiles**

Run: `mix compile --warnings-as-errors`
Expected: Compiles without warnings

**Step 3: Commit**

```bash
git add lib/gallformers_web/analytics/
git commit -m "Add LiveView on_mount hook for navigation tracking"
```

---

## Task 6: Wire up tracking in router

**Files:**
- Modify: `lib/gallformers_web/router.ex`

**Step 1: Add Plug to browser pipeline**

In `lib/gallformers_web/router.ex`, add to the `:browser` pipeline after `:fetch_current_user`:

```elixir
pipeline :browser do
  plug :accepts, ["html"]
  plug :fetch_session
  plug :fetch_live_flash
  plug :put_root_layout, html: {GallformersWeb.Layouts, :root}
  plug :protect_from_forgery
  plug :put_secure_browser_headers
  plug :fetch_current_user
  plug GallformersWeb.Plugs.Analytics
end
```

**Step 2: Add on_mount to public live_session**

Update the public live_session to include the analytics hook:

```elixir
live_session :public,
  on_mount: [
    {GallformersWeb.Live.UserAuth, :fetch_current_user},
    {GallformersWeb.Analytics.TrackPageView, :default}
  ] do
```

**Step 3: Verify it compiles**

Run: `mix compile --warnings-as-errors`
Expected: Compiles without warnings

**Step 4: Test manually**

Run: `mix phx.server`
Visit a few pages, then check the database:
```bash
sqlite3 priv/gallformers.sqlite "SELECT * FROM page_views LIMIT 5;"
```
Expected: Should see page view records

**Step 5: Commit**

```bash
git add lib/gallformers_web/router.ex
git commit -m "Wire up analytics tracking in router"
```

---

## Task 7: Create the admin dashboard LiveView

**Files:**
- Create: `lib/gallformers_web/live/admin/analytics_live.ex`

**Step 1: Create the dashboard LiveView**

Create `lib/gallformers_web/live/admin/analytics_live.ex`:

```elixir
defmodule GallformersWeb.Admin.AnalyticsLive do
  @moduledoc """
  Admin dashboard for viewing site analytics.
  """

  use GallformersWeb, :live_view

  alias Gallformers.Analytics

  @impl true
  def mount(_params, session, socket) do
    current_user = session["current_user"]

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:page_title, "Analytics")
      |> assign(:date_range, "7d")
      |> assign_date_range("7d")
      |> load_stats()

    {:ok, socket}
  end

  @impl true
  def handle_event("change_range", %{"range" => range}, socket) do
    socket =
      socket
      |> assign(:date_range, range)
      |> assign_date_range(range)
      |> load_stats()

    {:noreply, socket}
  end

  defp assign_date_range(socket, range) do
    today = Date.utc_today()

    {from_date, to_date} =
      case range do
        "today" -> {today, today}
        "7d" -> {Date.add(today, -6), today}
        "30d" -> {Date.add(today, -29), today}
        "90d" -> {Date.add(today, -89), today}
        _ -> {Date.add(today, -6), today}
      end

    socket
    |> assign(:from_date, from_date)
    |> assign(:to_date, to_date)
  end

  defp load_stats(socket) do
    from_date = socket.assigns.from_date
    to_date = socket.assigns.to_date

    socket
    |> assign(:stats, Analytics.stats(from_date, to_date))
    |> assign(:top_pages, Analytics.top_pages(from_date, to_date))
    |> assign(:top_referrers, Analytics.top_referrers(from_date, to_date))
    |> assign(:device_breakdown, Analytics.device_breakdown(from_date, to_date))
    |> assign(:browser_breakdown, Analytics.browser_breakdown(from_date, to_date))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} page_title="Analytics">
      <%!-- Date Range Selector --%>
      <div class="mb-6 flex items-center gap-2">
        <span class="text-sm text-gray-600">Date range:</span>
        <div class="flex gap-1">
          <.range_button range="today" current={@date_range} label="Today" />
          <.range_button range="7d" current={@date_range} label="7 days" />
          <.range_button range="30d" current={@date_range} label="30 days" />
          <.range_button range="90d" current={@date_range} label="90 days" />
        </div>
      </div>

      <%!-- Stats Summary --%>
      <div class="grid grid-cols-2 gap-4 mb-6">
        <div class="bg-white rounded-lg border border-gray-200 p-4">
          <div class="text-sm text-gray-500">Page Views</div>
          <div class="text-3xl font-semibold text-gray-900">
            {format_number(@stats.page_views)}
          </div>
        </div>
        <div class="bg-white rounded-lg border border-gray-200 p-4">
          <div class="text-sm text-gray-500">Unique Visitors</div>
          <div class="text-3xl font-semibold text-gray-900">
            {format_number(@stats.unique_visitors)}
          </div>
        </div>
      </div>

      <%!-- Top Pages --%>
      <div class="bg-white rounded-lg border border-gray-200 mb-6">
        <div class="px-4 py-3 border-b border-gray-200">
          <h2 class="text-lg font-medium text-gray-900">Top Pages</h2>
        </div>
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">
                  Page
                </th>
                <th class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase">
                  Views
                </th>
                <th class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase">
                  Unique
                </th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <tr :for={page <- @top_pages} class="hover:bg-gray-50">
                <td class="px-4 py-2 text-sm text-gray-900 font-mono">{page.path}</td>
                <td class="px-4 py-2 text-sm text-gray-600 text-right">
                  {format_number(page.views)}
                </td>
                <td class="px-4 py-2 text-sm text-gray-600 text-right">
                  {format_number(page.unique_visitors)}
                </td>
              </tr>
              <tr :if={@top_pages == []}>
                <td colspan="3" class="px-4 py-8 text-center text-gray-500">
                  No page views recorded yet
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <%!-- Referrers and Devices Row --%>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
        <%!-- Top Referrers --%>
        <div class="bg-white rounded-lg border border-gray-200">
          <div class="px-4 py-3 border-b border-gray-200">
            <h2 class="text-lg font-medium text-gray-900">Top Referrers</h2>
          </div>
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">
                    Source
                  </th>
                  <th class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase">
                    Views
                  </th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <tr :for={ref <- @top_referrers} class="hover:bg-gray-50">
                  <td class="px-4 py-2 text-sm text-gray-900">{ref.referrer}</td>
                  <td class="px-4 py-2 text-sm text-gray-600 text-right">
                    {format_number(ref.views)}
                  </td>
                </tr>
                <tr :if={@top_referrers == []}>
                  <td colspan="2" class="px-4 py-8 text-center text-gray-500">No data</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <%!-- Devices --%>
        <div class="bg-white rounded-lg border border-gray-200">
          <div class="px-4 py-3 border-b border-gray-200">
            <h2 class="text-lg font-medium text-gray-900">Devices</h2>
          </div>
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">
                    Type
                  </th>
                  <th class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase">
                    Count
                  </th>
                  <th class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase">
                    %
                  </th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <tr :for={device <- @device_breakdown} class="hover:bg-gray-50">
                  <td class="px-4 py-2 text-sm text-gray-900 capitalize">{device.device_type}</td>
                  <td class="px-4 py-2 text-sm text-gray-600 text-right">
                    {format_number(device.count)}
                  </td>
                  <td class="px-4 py-2 text-sm text-gray-600 text-right">
                    {percentage(device.count, @stats.page_views)}
                  </td>
                </tr>
                <tr :if={@device_breakdown == []}>
                  <td colspan="3" class="px-4 py-8 text-center text-gray-500">No data</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <%!-- Browsers --%>
      <div class="bg-white rounded-lg border border-gray-200">
        <div class="px-4 py-3 border-b border-gray-200">
          <h2 class="text-lg font-medium text-gray-900">Browsers</h2>
        </div>
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">
                  Browser
                </th>
                <th class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase">
                  Count
                </th>
                <th class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase">
                  %
                </th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <tr :for={browser <- @browser_breakdown} class="hover:bg-gray-50">
                <td class="px-4 py-2 text-sm text-gray-900">{browser.browser}</td>
                <td class="px-4 py-2 text-sm text-gray-600 text-right">
                  {format_number(browser.count)}
                </td>
                <td class="px-4 py-2 text-sm text-gray-600 text-right">
                  {percentage(browser.count, @stats.page_views)}
                </td>
              </tr>
              <tr :if={@browser_breakdown == []}>
                <td colspan="3" class="px-4 py-8 text-center text-gray-500">No data</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  # =================================================================
  # Private Components
  # =================================================================

  defp range_button(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="change_range"
      phx-value-range={@range}
      class={[
        "px-3 py-1 text-sm rounded-md transition-colors",
        if(@range == @current,
          do: "bg-gf-maroon text-white",
          else: "bg-gray-100 text-gray-700 hover:bg-gray-200"
        )
      ]}
    >
      {@label}
    </button>
    """
  end

  defp percentage(_count, 0), do: "0%"
  defp percentage(count, total), do: "#{Float.round(count / total * 100, 1)}%"
end
```

**Step 2: Verify it compiles**

Run: `mix compile --warnings-as-errors`
Expected: Compiles without warnings

**Step 3: Commit**

```bash
git add lib/gallformers_web/live/admin/analytics_live.ex
git commit -m "Add admin analytics dashboard LiveView"
```

---

## Task 8: Add route for analytics dashboard

**Files:**
- Modify: `lib/gallformers_web/router.ex`

**Step 1: Add the route**

In `lib/gallformers_web/router.ex`, add to the admin scope (after `live "/", Admin.DashboardLive`):

```elixir
live "/analytics", Admin.AnalyticsLive
```

**Step 2: Verify it compiles and works**

Run: `mix compile --warnings-as-errors`
Run: `mix phx.server`
Visit: http://localhost:4000/admin/analytics
Expected: Dashboard displays with stats

**Step 3: Commit**

```bash
git add lib/gallformers_web/router.ex
git commit -m "Add route for admin analytics dashboard"
```

---

## Task 9: Add analytics link to admin dashboard

**Files:**
- Modify: `lib/gallformers_web/live/admin/dashboard_live.ex`

**Step 1: Add stat card for analytics**

In the stats grid section, add an analytics stat card:

```elixir
<.stat_card title="Analytics" value="View" icon="ph-chart-line" href="/admin/analytics" />
```

**Step 2: Verify it compiles**

Run: `mix compile --warnings-as-errors`
Expected: Compiles without warnings

**Step 3: Commit**

```bash
git add lib/gallformers_web/live/admin/dashboard_live.ex
git commit -m "Add analytics link to admin dashboard"
```

---

## Task 10: Add tests

**Files:**
- Create: `test/gallformers/analytics_test.exs`

**Step 1: Create tests for the Analytics context**

Create `test/gallformers/analytics_test.exs`:

```elixir
defmodule Gallformers.AnalyticsTest do
  use Gallformers.DataCase, async: true

  alias Gallformers.Analytics
  alias Gallformers.Analytics.PageView

  describe "should_track?/2" do
    test "returns true for normal paths" do
      assert Analytics.should_track?("/", nil)
      assert Analytics.should_track?("/gall/123", "Mozilla/5.0")
      assert Analytics.should_track?("/species/456", "Chrome")
    end

    test "returns false for excluded paths" do
      refute Analytics.should_track?("/admin", nil)
      refute Analytics.should_track?("/admin/galls", nil)
      refute Analytics.should_track?("/api/v2/galls", nil)
      refute Analytics.should_track?("/assets/app.js", nil)
      refute Analytics.should_track?("/health", nil)
      refute Analytics.should_track?("/favicon.ico", nil)
    end

    test "returns false for bots" do
      refute Analytics.should_track?("/", "Googlebot/2.1")
      refute Analytics.should_track?("/", "bingbot/2.0")
      refute Analytics.should_track?("/", "Mozilla/5.0 (compatible; Slurp)")
      refute Analytics.should_track?("/", "facebookexternalhit/1.1")
    end
  end

  describe "generate_visitor_hash/2" do
    test "generates consistent hash for same inputs on same day" do
      hash1 = Analytics.generate_visitor_hash("192.168.1.1", "Mozilla/5.0")
      hash2 = Analytics.generate_visitor_hash("192.168.1.1", "Mozilla/5.0")
      assert hash1 == hash2
    end

    test "generates different hash for different IPs" do
      hash1 = Analytics.generate_visitor_hash("192.168.1.1", "Mozilla/5.0")
      hash2 = Analytics.generate_visitor_hash("192.168.1.2", "Mozilla/5.0")
      refute hash1 == hash2
    end

    test "generates 16-character hex string" do
      hash = Analytics.generate_visitor_hash("192.168.1.1", "Mozilla/5.0")
      assert String.length(hash) == 16
      assert String.match?(hash, ~r/^[0-9a-f]+$/)
    end
  end

  describe "extract_referrer_host/2" do
    test "extracts host from full URL" do
      assert Analytics.extract_referrer_host("https://google.com/search?q=galls", "gallformers.org") ==
               "google.com"
    end

    test "returns nil for same-site referrer" do
      assert Analytics.extract_referrer_host("https://gallformers.org/about", "gallformers.org") ==
               nil
    end

    test "returns nil for empty referrer" do
      assert Analytics.extract_referrer_host(nil, "gallformers.org") == nil
      assert Analytics.extract_referrer_host("", "gallformers.org") == nil
    end
  end

  describe "parse_user_agent/1" do
    test "returns nil for nil input" do
      assert Analytics.parse_user_agent(nil) == {nil, nil}
    end

    test "detects Chrome on desktop" do
      ua =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"

      {browser, device} = Analytics.parse_user_agent(ua)
      assert browser == "Chrome"
      assert device == "desktop"
    end

    test "detects Safari on mobile" do
      ua =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.1 Mobile/15E148 Safari/604.1"

      {browser, device} = Analytics.parse_user_agent(ua)
      assert browser == "Safari"
      assert device == "mobile"
    end
  end

  describe "track_page_view/1" do
    test "inserts a page view record" do
      attrs = %{
        path: "/test",
        referrer_host: "google.com",
        browser: "Chrome",
        device_type: "desktop",
        visitor_hash: "abc123"
      }

      assert :ok = Analytics.track_page_view(attrs)

      # Give async task time to complete
      Process.sleep(100)

      assert [page_view] = Repo.all(PageView)
      assert page_view.path == "/test"
      assert page_view.referrer_host == "google.com"
    end
  end

  describe "stats/2" do
    test "returns zeroes when no data" do
      today = Date.utc_today()
      stats = Analytics.stats(today, today)
      assert stats.page_views == 0
      assert stats.unique_visitors == 0
    end

    test "counts page views and unique visitors" do
      today = Date.utc_today()

      # Insert test data
      Repo.insert!(%PageView{
        path: "/",
        visitor_hash: "visitor1",
        inserted_at: DateTime.utc_now()
      })

      Repo.insert!(%PageView{
        path: "/about",
        visitor_hash: "visitor1",
        inserted_at: DateTime.utc_now()
      })

      Repo.insert!(%PageView{
        path: "/",
        visitor_hash: "visitor2",
        inserted_at: DateTime.utc_now()
      })

      stats = Analytics.stats(today, today)
      assert stats.page_views == 3
      assert stats.unique_visitors == 2
    end
  end
end
```

**Step 2: Run the tests**

Run: `mix test test/gallformers/analytics_test.exs`
Expected: All tests pass

**Step 3: Commit**

```bash
git add test/gallformers/analytics_test.exs
git commit -m "Add tests for Analytics context"
```

---

## Task 11: Final verification and cleanup

**Step 1: Run full test suite**

Run: `mix precommit`
Expected: All checks pass

**Step 2: Manual testing**

1. Start server: `mix phx.server`
2. Visit several public pages
3. Go to `/admin/analytics`
4. Verify stats are being recorded and displayed

**Step 3: Close the beads issue**

Run: `bd close gallformers-hcmb`

---

## Summary

| File | Action |
|------|--------|
| `mix.exs` | Add browser dependency |
| `priv/repo/migrations/*_create_page_views.exs` | Create |
| `lib/gallformers/analytics/page_view.ex` | Create |
| `lib/gallformers/analytics.ex` | Create |
| `lib/gallformers_web/plugs/analytics.ex` | Create |
| `lib/gallformers_web/analytics/track_page_view.ex` | Create |
| `lib/gallformers_web/router.ex` | Modify (add plug, on_mount, route) |
| `lib/gallformers_web/live/admin/analytics_live.ex` | Create |
| `lib/gallformers_web/live/admin/dashboard_live.ex` | Modify (add link) |
| `test/gallformers/analytics_test.exs` | Create |
