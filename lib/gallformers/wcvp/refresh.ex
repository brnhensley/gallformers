defmodule Gallformers.Wcvp.Refresh do
  @moduledoc """
  Handles downloading and hot-swapping the WCVP SQLite database.
  """

  alias Gallformers.Repo

  require Logger

  @download_url "https://gallformers-backups.s3.amazonaws.com/public/wcvp.sqlite"

  def refresh do
    db_path = Application.get_env(:gallformers, Repo.WCVP)[:database]
    tmp_path = db_path <> ".tmp"

    with :ok <- stop_repo(),
         :ok <- download(tmp_path),
         :ok <- swap_file(tmp_path, db_path),
         :ok <- start_repo() do
      Logger.info("WCVP database refreshed successfully")
      {:ok, :refreshed}
    else
      {:error, reason} = error ->
        Logger.error("WCVP refresh failed: #{inspect(reason)}")
        if File.exists?(db_path), do: start_repo()
        error
    end
  end

  defp stop_repo do
    Repo.WCVP.stop()
  end

  defp start_repo do
    case Repo.WCVP.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      error -> error
    end
  end

  defp download(dest_path) do
    Logger.info("Downloading WCVP database from #{@download_url}...")
    File.mkdir_p!(Path.dirname(dest_path))

    case Req.get(@download_url, into: File.stream!(dest_path)) do
      {:ok, %Req.Response{status: 200}} ->
        :ok

      {:ok, %Req.Response{status: status}} ->
        File.rm(dest_path)
        {:error, {:download_failed, status}}

      {:error, reason} ->
        File.rm(dest_path)
        {:error, {:download_failed, reason}}
    end
  end

  defp swap_file(tmp_path, dest_path) do
    File.rename(tmp_path, dest_path)
  end
end
