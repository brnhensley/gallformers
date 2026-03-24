defmodule Gallformers.Async do
  @moduledoc """
  Helpers for running background tasks.

  In production, tasks run asynchronously via Task.start.
  In tests, tasks run synchronously to avoid sandbox connection issues.
  """
  use Boundary, deps: [], exports: :all

  @doc """
  Runs a function asynchronously in production, synchronously in tests.

  Configure via `config :gallformers, async_tasks: false` to run synchronously.
  """
  @spec run((-> any())) :: :ok
  def run(fun) when is_function(fun, 0) do
    if Application.get_env(:gallformers, :async_tasks, true) do
      Task.start(fun)
    else
      fun.()
    end

    :ok
  end
end
