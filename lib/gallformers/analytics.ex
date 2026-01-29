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
    {detect_browser(user_agent), detect_device_type(user_agent)}
  end

  defp detect_browser(user_agent) do
    cond do
      Browser.chrome?(user_agent) -> "Chrome"
      Browser.firefox?(user_agent) -> "Firefox"
      Browser.safari?(user_agent) -> "Safari"
      Browser.edge?(user_agent) -> "Edge"
      Browser.opera?(user_agent) -> "Opera"
      Browser.ie?(user_agent) -> "IE"
      true -> "Other"
    end
  end

  defp detect_device_type(user_agent) do
    cond do
      Browser.mobile?(user_agent) -> "mobile"
      Browser.tablet?(user_agent) -> "tablet"
      true -> "desktop"
    end
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
