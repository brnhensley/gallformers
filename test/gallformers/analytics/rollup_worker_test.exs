defmodule Gallformers.Analytics.RollupWorkerTest do
  use Gallformers.DataCase

  alias Gallformers.Analytics.PageView
  alias Gallformers.Analytics.RollupWorker

  test "rolls up pending days and prunes old page views" do
    yesterday = Date.add(Date.utc_today(), -1)
    old_date = Date.add(Date.utc_today(), -100)

    Repo.insert!(%PageView{
      path: "/rolled-up",
      visitor_hash: "visitor-1",
      referrer_host: "google.com",
      browser: "Firefox",
      device_type: "desktop",
      inserted_at: NaiveDateTime.new!(yesterday, ~T[12:00:00])
    })

    Repo.insert!(%PageView{
      path: "/old",
      visitor_hash: "visitor-old",
      referrer_host: nil,
      browser: "Chrome",
      device_type: "mobile",
      inserted_at: NaiveDateTime.new!(old_date, ~T[12:00:00])
    })

    assert :ok = RollupWorker.perform(%Oban.Job{})

    assert %{rows: [[1, 1]]} =
             Repo.query!(
               "SELECT page_views, unique_visitors FROM daily_stats WHERE date = $1",
               [yesterday]
             )

    assert %{num_rows: 0} = Repo.query!("SELECT * FROM page_views WHERE path = '/old'")
  end
end
