defmodule Gallformers.Analytics.RollupWorker do
  @moduledoc """
  Scheduled Oban worker that runs the daily analytics rollup and pruning.

  Cron enqueues this worker at 07:00 UTC. The worker itself keeps the durable,
  retryable execution boundary thin and delegates the actual aggregation logic
  to `Gallformers.Analytics.Rollup`.
  """

  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 5

  require Logger

  alias Gallformers.Analytics.Rollup

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    case Rollup.rollup_pending_days() do
      {:ok, 0} ->
        Logger.debug("Analytics rollup: no pending days")

      {:ok, count} ->
        Logger.info("Analytics rollup: processed #{count} day(s)")
    end

    {pruned, _} = Rollup.prune_old_page_views()

    if pruned > 0 do
      Logger.info("Analytics rollup: pruned #{pruned} old page views")
    end

    :ok
  end
end
