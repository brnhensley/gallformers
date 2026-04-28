defmodule Gallformers.IngestionPipeline.Storage do
  @moduledoc """
  S3-backed artifact storage for ingestion pipeline outputs.
  """

  use Boundary,
    deps: [Gallformers.Ingestions, Gallformers.Storage],
    exports: :all

  alias Gallformers.Ingestions
  alias Gallformers.Storage.SourceArtifacts

  @type stage :: atom() | String.t()

  defmodule Backend do
    @moduledoc false

    @callback upload(String.t(), String.t(), binary(), String.t()) ::
                {:ok, term()} | {:error, term()}
    @callback get_object(String.t(), String.t()) :: {:ok, map()} | {:error, term()}

    @callback list_objects(String.t(), String.t(), String.t() | nil) ::
                {:ok, %{keys: [String.t()], next_continuation_token: String.t() | nil}}
                | {:error, term()}

    @callback delete_objects(String.t(), [String.t()]) :: {:ok, term()} | {:error, term()}
  end

  defmodule DefaultBackend do
    @moduledoc false

    @behaviour Gallformers.IngestionPipeline.Storage.Backend

    alias Gallformers.Storage.S3

    @impl true
    def upload(bucket, path, content, content_type) do
      ExAws.S3.put_object(bucket, path, content, content_type: content_type)
      |> S3.request()
    end

    @impl true
    def get_object(bucket, path) do
      bucket
      |> ExAws.S3.get_object(path)
      |> S3.request()
    end

    @impl true
    def list_objects(bucket, prefix, continuation_token) do
      opts =
        [prefix: prefix]
        |> maybe_put_continuation_token(continuation_token)

      case ExAws.S3.list_objects_v2(bucket, opts) |> S3.request() do
        {:ok, %{body: body}} ->
          {:ok,
           %{
             keys: extract_keys(body),
             next_continuation_token: next_continuation_token(body)
           }}

        {:error, reason} ->
          {:error, reason}
      end
    end

    @impl true
    def delete_objects(bucket, keys) do
      ExAws.S3.delete_multiple_objects(bucket, keys)
      |> S3.request()
    end

    defp maybe_put_continuation_token(opts, nil), do: opts

    defp maybe_put_continuation_token(opts, continuation_token) do
      Keyword.put(opts, :continuation_token, continuation_token)
    end

    defp extract_keys(body) do
      body
      |> Map.get(:contents, Map.get(body, "contents", []))
      |> List.wrap()
      |> Enum.map(fn entry -> Map.get(entry, :key, Map.get(entry, "key")) end)
      |> Enum.reject(&is_nil/1)
    end

    defp next_continuation_token(body) do
      Map.get(body, :next_continuation_token, Map.get(body, "next_continuation_token"))
    end
  end

  @doc """
  Returns the S3 key for a pipeline artifact.
  """
  @spec artifact_path(integer(), stage(), String.t()) :: String.t()
  def artifact_path(ingestion_id, stage, filename)
      when is_integer(ingestion_id) and is_binary(filename) do
    Path.join([
      Ingestions.artifacts_path_for(ingestion_id),
      normalize_stage(stage),
      filename
    ])
  end

  @doc """
  Uploads an artifact to S3 and returns its S3 key.
  """
  @spec upload_artifact(integer(), stage(), String.t(), binary(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
  def upload_artifact(ingestion_id, stage, filename, content, content_type)
      when is_binary(content) and is_binary(content_type) do
    path = artifact_path(ingestion_id, stage, filename)

    case backend().upload(private_bucket(), path, content, content_type) do
      {:ok, _response} -> {:ok, path}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Downloads an artifact from S3.
  """
  @spec download_artifact(integer(), stage(), String.t()) :: {:ok, binary()} | {:error, term()}
  def download_artifact(ingestion_id, stage, filename) do
    path = artifact_path(ingestion_id, stage, filename)

    case backend().get_object(private_bucket(), path) do
      {:ok, %{body: body}} when is_binary(body) -> {:ok, body}
      {:ok, body} when is_binary(body) -> {:ok, body}
      {:error, reason} when reason in [:not_found, :no_such_key] -> {:error, :not_found}
      {:error, reason} -> normalize_download_error(reason)
    end
  end

  @doc """
  Lists every artifact key stored for an ingestion under its canonical prefix.
  """
  @spec list_artifacts_for_ingestion(integer()) :: {:ok, [String.t()]} | {:error, term()}
  def list_artifacts_for_ingestion(ingestion_id) when is_integer(ingestion_id) do
    ingestion_id
    |> artifact_prefix()
    |> list_artifact_keys()
    |> case do
      {:ok, keys} -> {:ok, Enum.sort(keys)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Deletes every artifact stored for an ingestion under its canonical prefix.
  """
  @spec delete_artifacts_for_ingestion(integer()) :: :ok | {:error, term()}
  def delete_artifacts_for_ingestion(ingestion_id) when is_integer(ingestion_id) do
    case list_artifacts_for_ingestion(ingestion_id) do
      {:ok, keys} -> delete_keys(keys)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns the private bucket used for ingestion artifacts.
  """
  @spec private_bucket() :: String.t()
  def private_bucket do
    SourceArtifacts.private_bucket()
  end

  defp backend do
    Application.get_env(:gallformers, __MODULE__, [])
    |> Keyword.get(:backend, DefaultBackend)
  end

  defp artifact_prefix(ingestion_id) do
    "#{Ingestions.artifacts_path_for(ingestion_id)}/"
  end

  defp list_artifact_keys(prefix, continuation_token \\ nil, acc \\ []) do
    case backend().list_objects(private_bucket(), prefix, continuation_token) do
      {:ok, %{keys: keys, next_continuation_token: nil}} ->
        {:ok, Enum.reverse(acc, keys)}

      {:ok, %{keys: keys, next_continuation_token: next_token}} ->
        list_artifact_keys(prefix, next_token, Enum.reverse(keys, acc))

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp delete_keys([]), do: :ok

  defp delete_keys(keys) do
    case backend().delete_objects(private_bucket(), keys) do
      {:ok, _response} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_stage(stage) when is_atom(stage), do: Atom.to_string(stage)
  defp normalize_stage(stage) when is_binary(stage), do: stage

  defp normalize_download_error({:http_error, 404, _details}), do: {:error, :not_found}
  defp normalize_download_error(%{status_code: 404}), do: {:error, :not_found}
  defp normalize_download_error(%{reason: :not_found}), do: {:error, :not_found}
  defp normalize_download_error(reason), do: {:error, reason}
end
