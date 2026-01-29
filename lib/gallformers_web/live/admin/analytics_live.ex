defmodule GallformersWeb.Admin.AnalyticsLive do
  @moduledoc """
  Admin dashboard for viewing site analytics.

  Displays page views, unique visitors, top pages, referrers,
  device types, and browser breakdown for a configurable date range.
  """

  use GallformersWeb, :live_view

  alias Gallformers.Analytics

  @default_range "7d"
  @ranges %{
    "today" => 0,
    "7d" => 6,
    "30d" => 29,
    "90d" => 89
  }

  @impl true
  def mount(_params, session, socket) do
    current_user = session["current_user"]

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:page_title, "Analytics")
      |> assign(:current_range, @default_range)
      |> load_analytics(@default_range)

    {:ok, socket}
  end

  @impl true
  def handle_event("change_range", %{"range" => range}, socket) do
    socket =
      socket
      |> assign(:current_range, range)
      |> load_analytics(range)

    {:noreply, socket}
  end

  defp load_analytics(socket, range) do
    {from_date, to_date} = date_range(range)

    socket
    |> assign(:stats, Analytics.stats(from_date, to_date))
    |> assign(:top_pages, Analytics.top_pages(from_date, to_date))
    |> assign(:top_referrers, Analytics.top_referrers(from_date, to_date))
    |> assign(:devices, add_percentages(Analytics.device_breakdown(from_date, to_date)))
    |> assign(:browsers, add_percentages(Analytics.browser_breakdown(from_date, to_date)))
  end

  defp date_range(range) do
    days_ago = Map.get(@ranges, range, 6)
    to_date = Date.utc_today()
    from_date = Date.add(to_date, -days_ago)
    {from_date, to_date}
  end

  defp add_percentages(items) do
    total = Enum.reduce(items, 0, fn item, acc -> acc + item.count end)

    Enum.map(items, fn item ->
      percentage = if total > 0, do: Float.round(item.count / total * 100, 1), else: 0.0
      Map.put(item, :percentage, percentage)
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} page_title="Analytics">
      <div class="space-y-6">
        <%!-- Date Range Selector --%>
        <div class="flex items-center gap-2">
          <span class="text-sm text-gray-600">Period:</span>
          <.range_button range="today" label="Today" current={@current_range} />
          <.range_button range="7d" label="7 days" current={@current_range} />
          <.range_button range="30d" label="30 days" current={@current_range} />
          <.range_button range="90d" label="90 days" current={@current_range} />
        </div>

        <%!-- Stats Summary --%>
        <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <.stat_card title="Page Views" value={@stats.page_views} icon="ph-eye" />
          <.stat_card title="Unique Visitors" value={@stats.unique_visitors} icon="ph-users" />
        </div>

        <%!-- Top Pages --%>
        <div class="bg-white rounded-lg border border-gray-200 overflow-hidden">
          <div class="px-4 py-3 border-b border-gray-200 bg-gray-50">
            <h3 class="text-lg font-semibold text-gray-900">Top Pages</h3>
          </div>
          <table class="gf-table gf-table-dense">
            <thead>
              <tr>
                <th>Path</th>
                <th class="text-right">Views</th>
                <th class="text-right">Unique Visitors</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={page <- @top_pages}>
                <td class="font-mono text-sm">{page.path}</td>
                <td class="text-right">{format_number(page.views)}</td>
                <td class="text-right">{format_number(page.unique_visitors)}</td>
              </tr>
              <tr :if={@top_pages == []}>
                <td colspan="3" class="text-center text-gray-500 py-8">
                  No page views recorded for this period.
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <%!-- Two Column Layout for Referrers and Device/Browser --%>
        <div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
          <%!-- Top Referrers --%>
          <div class="bg-white rounded-lg border border-gray-200 overflow-hidden">
            <div class="px-4 py-3 border-b border-gray-200 bg-gray-50">
              <h3 class="text-lg font-semibold text-gray-900">Top Referrers</h3>
            </div>
            <table class="gf-table gf-table-dense">
              <thead>
                <tr>
                  <th>Source</th>
                  <th class="text-right">Views</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={referrer <- @top_referrers}>
                  <td>{referrer.referrer}</td>
                  <td class="text-right">{format_number(referrer.views)}</td>
                </tr>
                <tr :if={@top_referrers == []}>
                  <td colspan="2" class="text-center text-gray-500 py-8">
                    No referrer data for this period.
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <%!-- Devices and Browsers --%>
          <div class="space-y-6">
            <%!-- Devices --%>
            <div class="bg-white rounded-lg border border-gray-200 overflow-hidden">
              <div class="px-4 py-3 border-b border-gray-200 bg-gray-50">
                <h3 class="text-lg font-semibold text-gray-900">Devices</h3>
              </div>
              <table class="gf-table gf-table-dense">
                <thead>
                  <tr>
                    <th>Type</th>
                    <th class="text-right">Count</th>
                    <th class="text-right">%</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={device <- @devices}>
                    <td class="capitalize">{device.device_type}</td>
                    <td class="text-right">{format_number(device.count)}</td>
                    <td class="text-right">{device.percentage}%</td>
                  </tr>
                  <tr :if={@devices == []}>
                    <td colspan="3" class="text-center text-gray-500 py-8">
                      No device data for this period.
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>

            <%!-- Browsers --%>
            <div class="bg-white rounded-lg border border-gray-200 overflow-hidden">
              <div class="px-4 py-3 border-b border-gray-200 bg-gray-50">
                <h3 class="text-lg font-semibold text-gray-900">Browsers</h3>
              </div>
              <table class="gf-table gf-table-dense">
                <thead>
                  <tr>
                    <th>Browser</th>
                    <th class="text-right">Count</th>
                    <th class="text-right">%</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={browser <- @browsers}>
                    <td>{browser.browser}</td>
                    <td class="text-right">{format_number(browser.count)}</td>
                    <td class="text-right">{browser.percentage}%</td>
                  </tr>
                  <tr :if={@browsers == []}>
                    <td colspan="3" class="text-center text-gray-500 py-8">
                      No browser data for this period.
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
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

  defp stat_card(assigns) do
    ~H"""
    <div class="bg-white rounded-lg border border-gray-200 p-4">
      <div class="flex items-center">
        <div class="flex-shrink-0">
          <div class="rounded-md bg-gf-maroon/10 p-3">
            <.icon name={@icon} class="h-6 w-6 text-gf-maroon" />
          </div>
        </div>
        <div class="ml-4">
          <dt class="text-sm font-medium text-gray-500">{@title}</dt>
          <dd class="text-2xl font-semibold text-gray-900">{format_number(@value)}</dd>
        </div>
      </div>
    </div>
    """
  end
end
