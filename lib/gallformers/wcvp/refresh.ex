defmodule Gallformers.Wcvp.Refresh do
  @moduledoc """
  WCVP database refresh operations.

  Phase 1: Manual refresh via pg_restore. Use `mix gallformers.wcvp.restore`
  for local dev, or pg_restore via fly proxy for prod/preview.

  Phase 2 (matter 0ae0): Automated refresh via a dedicated worker machine.
  """

  @doc """
  Returns instructions for refreshing the WCVP database.

  Automated refresh is not yet implemented. Use manual pg_restore workflow:

  - Local dev: `mix gallformers.wcvp.restore`
  - Prod/Preview: pg_restore via fly proxy from S3 dump
  """
  @spec refresh() :: {:error, :manual_restore_required}
  def refresh do
    {:error, :manual_restore_required}
  end
end
