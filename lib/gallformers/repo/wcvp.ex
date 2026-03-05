defmodule Gallformers.Repo.WCVP do
  @moduledoc """
  Read-only Ecto repo for querying the WCVP SQLite database.

  This is a secondary database containing filtered WCVP plant data
  (accepted species with distribution in any mapped TDWG region). It is NOT
  managed by Ecto migrations — the database file is built externally and
  downloaded from S3.
  """
  use Ecto.Repo,
    otp_app: :gallformers,
    adapter: Ecto.Adapters.SQLite3
end
