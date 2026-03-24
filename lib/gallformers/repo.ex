defmodule Gallformers.Repo do
  use Boundary, deps: [], exports: :all

  use Ecto.Repo,
    otp_app: :gallformers,
    adapter: Ecto.Adapters.Postgres
end
