defmodule Gallformers.Analytics.Rollup do
  @moduledoc """
  GenServer that aggregates raw `page_views` into daily summary tables.

  Runs nightly at ~07:00 UTC (3:00 AM ET) to roll up pending days and prune
  old raw rows. Gap-aware: retries any previously failed days rather than
  skipping over them.
  """

  use GenServer

  import Ecto.Query

  require Logger

  alias Gallformers.Analytics.PageView
  alias Gallformers.Repo

  @default_prune_days 30

  # -- Public API --

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Rolls up all pending days through yesterday.

  Finds dates that have raw page_views but no corresponding daily_stats
  entry, then processes each one. Gap-aware: previously failed days are
  retried on the next run rather than skipped permanently.

  Individual day failures are logged and skipped — they don't prevent
  subsequent days from being processed.

  Returns `{:ok, count}` where count is the number of days successfully rolled up.
  """
  @spec rollup_pending_days() :: {:ok, non_neg_integer()}
  def rollup_pending_days do
    dates = pending_dates()

    count =
      Enum.reduce(dates, 0, fn date, acc ->
        try do
          case rollup_day(date) do
            :ok -> acc + 1
            :noop -> acc
          end
        rescue
          e ->
            Logger.error("Analytics rollup failed for #{date}: #{Exception.message(e)}")
            acc
        end
      end)

    {:ok, count}
  end

  # Returns dates that need rolling up — finds gaps in daily_stats where
  # page_views exist but no rollup has been recorded. This ensures failed
  # days are retried rather than permanently skipped.
  defp pending_dates do
    yesterday = Date.utc_today() |> Date.add(-1)

    %{rows: rows} =
      Repo.query!(
        """
        SELECT DISTINCT inserted_at::date FROM page_views
        WHERE inserted_at::date NOT IN (SELECT date FROM daily_stats)
          AND inserted_at::date <= $1
        ORDER BY inserted_at::date
        """,
        [yesterday]
      )

    Enum.map(rows, fn [date] -> date end)
  end

  @doc """
  Aggregates a single day's raw page_views into the 5 summary tables.

  Idempotent: uses DELETE + INSERT for multi-row tables, INSERT ... ON CONFLICT
  for the single-row daily_stats. Returns `:noop` if no raw data exists
  for the given day.
  """
  @spec rollup_day(Date.t()) :: :ok | :noop
  def rollup_day(date) do
    {from_dt, to_dt} = date_bounds(date)

    base_query =
      from(pv in PageView,
        where: pv.inserted_at >= ^from_dt and pv.inserted_at < ^to_dt
      )

    count = Repo.aggregate(base_query, :count)

    if count == 0 do
      :noop
    else
      # Each summary table is rolled up independently. Every operation is
      # idempotent (DELETE + INSERT or ON CONFLICT), so partial completion
      # is safe — the next run will fill any gaps.
      rollup_daily_stats(base_query, date)
      rollup_daily_page_stats(base_query, date)
      rollup_daily_referrer_stats(base_query, date)
      rollup_daily_device_stats(base_query, date)
      rollup_daily_browser_stats(base_query, date)

      :ok
    end
  end

  @doc """
  Deletes raw page_views older than `days` days. Returns `{count, nil}`.
  """
  @spec prune_old_page_views(integer()) :: {non_neg_integer(), nil}
  def prune_old_page_views(days \\ @default_prune_days) do
    cutoff = NaiveDateTime.new!(Date.add(Date.utc_today(), -days), ~T[00:00:00])

    from(pv in PageView, where: pv.inserted_at < ^cutoff)
    |> Repo.delete_all()
  end

  # -- GenServer callbacks --

  @impl true
  def init(_opts) do
    schedule_next_run()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:run_rollup, state) do
    try do
      case rollup_pending_days() do
        {:ok, 0} ->
          Logger.debug("Analytics rollup: no pending days")

        {:ok, count} ->
          Logger.info("Analytics rollup: processed #{count} day(s)")
      end

      {pruned, _} = prune_old_page_views()

      if pruned > 0 do
        Logger.info("Analytics rollup: pruned #{pruned} old page views")
      end
    rescue
      e ->
        Logger.error("Analytics rollup crashed: #{Exception.message(e)}")
    end

    schedule_next_run()
    {:noreply, state}
  end

  # -- Private --

  defp schedule_next_run do
    ms = ms_until_next_run()
    Process.send_after(self(), :run_rollup, ms)
  end

  defp ms_until_next_run do
    now = NaiveDateTime.utc_now()
    today = NaiveDateTime.to_date(now)
    # Target: 07:00 UTC (3:00 AM ET) — low-traffic window
    target = NaiveDateTime.new!(Date.add(today, 1), ~T[07:00:00])
    max(NaiveDateTime.diff(target, now, :millisecond), 1_000)
  end

  defp date_bounds(date) do
    {NaiveDateTime.new!(date, ~T[00:00:00]), NaiveDateTime.new!(Date.add(date, 1), ~T[00:00:00])}
  end

  defp rollup_daily_stats(base_query, date) do
    %{page_views: pv, unique_visitors: uv} =
      from(pv in base_query,
        select: %{
          page_views: count(pv.id),
          unique_visitors: count(pv.visitor_hash, :distinct)
        }
      )
      |> Repo.one!()

    Repo.query!(
      """
      INSERT INTO daily_stats (date, page_views, unique_visitors) VALUES ($1, $2, $3)
      ON CONFLICT (date) DO UPDATE SET page_views = EXCLUDED.page_views, unique_visitors = EXCLUDED.unique_visitors
      """,
      [date, pv, uv]
    )
  end

  defp rollup_daily_page_stats(base_query, date) do
    rows =
      from(pv in base_query,
        group_by: pv.path,
        select: {pv.path, count(pv.id), count(pv.visitor_hash, :distinct)}
      )
      |> Repo.all()

    Repo.query!("DELETE FROM daily_page_stats WHERE date = $1", [date])

    batch_insert("daily_page_stats", ["date", "path", "page_views", "unique_visitors"], fn ->
      Enum.map(rows, fn {path, views, unique} -> [date, path, views, unique] end)
    end)
  end

  defp rollup_daily_referrer_stats(base_query, date) do
    rows =
      from(pv in base_query,
        group_by: pv.referrer_host,
        select: {pv.referrer_host, count(pv.id)}
      )
      |> Repo.all()

    Repo.query!("DELETE FROM daily_referrer_stats WHERE date = $1", [date])

    batch_insert("daily_referrer_stats", ["date", "referrer_host", "page_views"], fn ->
      Enum.map(rows, fn {referrer, views} -> [date, referrer, views] end)
    end)
  end

  defp rollup_daily_device_stats(base_query, date) do
    rows =
      from(pv in base_query,
        group_by: pv.device_type,
        select: {pv.device_type, count(pv.id)}
      )
      |> Repo.all()

    Repo.query!("DELETE FROM daily_device_stats WHERE date = $1", [date])

    batch_insert("daily_device_stats", ["date", "device_type", "count"], fn ->
      Enum.map(rows, fn {device, cnt} -> [date, device, cnt] end)
    end)
  end

  defp rollup_daily_browser_stats(base_query, date) do
    rows =
      from(pv in base_query,
        group_by: pv.browser,
        select: {pv.browser, count(pv.id)}
      )
      |> Repo.all()

    Repo.query!("DELETE FROM daily_browser_stats WHERE date = $1", [date])

    batch_insert("daily_browser_stats", ["date", "browser", "count"], fn ->
      Enum.map(rows, fn {browser, cnt} -> [date, browser, cnt] end)
    end)
  end

  # Inserts rows in batches using multi-row VALUES clauses.
  # Reduces 10,000+ individual round trips to ~10 batched statements.
  @batch_size 1000
  defp batch_insert(table, columns, rows_fn) do
    rows = rows_fn.()

    if rows != [] do
      col_list = Enum.join(columns, ", ")
      num_cols = length(columns)

      rows
      |> Enum.chunk_every(@batch_size)
      |> Enum.each(fn batch ->
        {values, params} = build_values_clause(batch, num_cols)
        Repo.query!("INSERT INTO #{table} (#{col_list}) VALUES #{values}", params)
      end)
    end
  end

  defp build_values_clause(batch, num_cols) do
    {placeholders, _} =
      Enum.map_reduce(batch, 1, fn _row, idx ->
        params = Enum.map_join(idx..(idx + num_cols - 1), ", ", &"$#{&1}")
        {"(#{params})", idx + num_cols}
      end)

    {Enum.join(placeholders, ", "), List.flatten(batch)}
  end
end
