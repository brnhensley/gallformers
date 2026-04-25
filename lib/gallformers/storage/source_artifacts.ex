defmodule Gallformers.Storage.SourceArtifacts do
  @moduledoc """
  Storage helpers for private ingestion artifacts and public published-source
  artifacts.
  """

  alias Gallformers.S3

  defmodule Backend do
    @moduledoc false

    @callback copy_object(String.t(), String.t(), String.t(), String.t()) ::
                {:ok, term()} | {:error, term()}
  end

  defmodule DefaultBackend do
    @moduledoc false

    @behaviour Gallformers.Storage.SourceArtifacts.Backend

    @impl true
    def copy_object(dest_bucket, dest_path, src_bucket, src_path) do
      ExAws.S3.put_object_copy(dest_bucket, dest_path, src_bucket, src_path)
      |> S3.request()
    end
  end

  @doc """
  Returns the private bucket used for ingestion uploads and pipeline artifacts.
  """
  @spec private_bucket() :: String.t()
  def private_bucket do
    storage_config()[:private_bucket]
  end

  @doc """
  Returns the public bucket used for published source artifacts.
  """
  @spec public_bucket() :: String.t()
  def public_bucket do
    storage_config()[:public_bucket]
  end

  @doc """
  Returns the public base URL for published source artifacts.
  """
  @spec public_base_url() :: String.t()
  def public_base_url do
    storage_config()[:public_base_url]
  end

  @doc """
  Builds a public URL for a published source artifact path.
  """
  @spec public_url(String.t()) :: String.t()
  def public_url(path) when is_binary(path) do
    base_url = public_base_url() |> String.trim_trailing("/")
    path = String.trim_leading(path, "/")
    "#{base_url}/#{path}"
  end

  @doc """
  Copies a private ingestion artifact to a public published-source path.
  """
  @spec copy_private_to_public(String.t(), String.t()) ::
          {:ok, %{bucket: String.t(), path: String.t(), url: String.t()}}
          | {:error, term()}
  def copy_private_to_public(private_path, public_path)
      when is_binary(private_path) and is_binary(public_path) do
    case backend().copy_object(public_bucket(), public_path, private_bucket(), private_path) do
      {:ok, _response} ->
        {:ok, %{bucket: public_bucket(), path: public_path, url: public_url(public_path)}}

      {:error, reason} ->
        normalize_copy_error(reason)
    end
  end

  defp backend do
    Application.get_env(:gallformers, __MODULE__, [])
    |> Keyword.get(:backend, DefaultBackend)
  end

  defp storage_config do
    Application.get_env(:gallformers, :source_storage, [])
  end

  defp normalize_copy_error(reason) when reason in [:not_found, :no_such_key] do
    {:error, :private_artifact_not_found}
  end

  defp normalize_copy_error({:http_error, 404, _details}) do
    {:error, :private_artifact_not_found}
  end

  defp normalize_copy_error(%{status_code: 404}) do
    {:error, :private_artifact_not_found}
  end

  defp normalize_copy_error(%{reason: :not_found}) do
    {:error, :private_artifact_not_found}
  end

  defp normalize_copy_error(reason), do: {:error, reason}
end
