defmodule Gallformers.Wcvp.Conn do
  @moduledoc false

  @doc """
  Derives Postgrex connection options from the Repo.WCVP application config,
  with env var fallbacks for credentials. Used by mix tasks that need a direct
  Postgrex connection outside of the Ecto repo (build_db, restore).

  Accepts an optional keyword list to override specific keys (e.g., `database`).
  """
  @spec opts(keyword()) :: keyword()
  def opts(overrides \\ []) do
    repo_config = Application.get_env(:gallformers, Gallformers.Repo.WCVP, [])

    base = [
      database: repo_config[:database] || "wcvp",
      username: repo_config[:username] || System.get_env("PGUSER") || System.get_env("USER"),
      password: repo_config[:password] || System.get_env("PGPASSWORD"),
      hostname: repo_config[:hostname] || System.get_env("PGHOST") || "localhost"
    ]

    Keyword.merge(base, overrides)
  end

  @doc """
  Opens a direct Postgrex connection using the resolved config.
  """
  @spec start_link!(keyword()) :: pid()
  def start_link!(overrides \\ []) do
    {:ok, conn} = Postgrex.start_link(opts(overrides))
    conn
  end
end
