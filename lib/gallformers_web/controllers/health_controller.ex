defmodule GallformersWeb.HealthController do
  use GallformersWeb, :controller

  alias Gallformers.Repo

  def check(conn, _params) do
    case check_database() do
      :ok ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(200, "ok")

      {:error, reason} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(503, "database unavailable: #{inspect(reason)}")
    end
  end

  defp check_database do
    case Repo.query("SELECT 1") do
      {:ok, _result} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
