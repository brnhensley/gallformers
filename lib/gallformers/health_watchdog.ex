defmodule Gallformers.HealthWatchdog do
  @moduledoc """
  Monitors application health and stops the VM when the app becomes unresponsive.

  Fly.io health checks only affect routing — they don't restart machines. This
  watchdog fills that gap: if the database becomes unreachable for several
  consecutive checks, it stops the BEAM so Fly's on-failure restart policy
  can bring it back.
  """
  use GenServer
  require Logger

  @check_interval :timer.seconds(30)
  @max_failures 5
  @db_timeout :timer.seconds(5)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    schedule_check()
    {:ok, %{failures: 0}}
  end

  @impl true
  def handle_info(:check, state) do
    case check_health() do
      :ok ->
        schedule_check()
        {:noreply, %{state | failures: 0}}

      :error ->
        failures = state.failures + 1

        if failures >= @max_failures do
          Logger.error(
            "Health watchdog: #{failures} consecutive failures, stopping VM for restart"
          )

          System.stop(1)
          {:noreply, state}
        else
          Logger.warning("Health watchdog: failure #{failures}/#{@max_failures}")
          schedule_check()
          {:noreply, %{state | failures: failures}}
        end
    end
  end

  defp check_health do
    task = Task.async(fn -> Gallformers.Repo.query("SELECT 1") end)

    case Task.yield(task, @db_timeout) || Task.shutdown(task) do
      {:ok, {:ok, _}} -> :ok
      _ -> :error
    end
  end

  defp schedule_check do
    Process.send_after(self(), :check, @check_interval)
  end
end
