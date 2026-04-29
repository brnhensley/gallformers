defmodule Gallformers.Storage.S3 do
  @moduledoc """
  S3 wrapper that respects `s3_enabled` config for test isolation.

  All S3 operations should go through this module instead of calling
  `ExAws` directly. This ensures tests never make real AWS calls and keeps
  ExAws configuration details behind a single storage boundary.

  ## Configuration

      # config/test.exs
      config :gallformers, s3_enabled: false

  ## Usage

      # Instead of:
      ExAws.S3.put_object(bucket, path, data) |> ExAws.request()

      # Use:
      ExAws.S3.put_object(bucket, path, data) |> Gallformers.Storage.S3.request()

      # For presigned URLs:
      Gallformers.Storage.S3.presigned_url(:put, bucket, path, opts)
  """
  use Boundary, deps: [], exports: :all

  require Logger

  @doc """
  Generates a presigned URL, respecting the `s3_enabled` config.

  Returns a deterministic mock URL when S3 is disabled so tests do not depend
  on AWS credentials or ExAws runtime configuration.
  """
  @spec presigned_url(atom(), String.t(), String.t(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def presigned_url(http_method, bucket, path, opts \\ []) do
    if s3_enabled?() do
      config = ExAws.Config.new(:s3)
      ExAws.S3.presigned_url(config, http_method, bucket, path, opts)
    else
      {:ok, mock_presigned_url(http_method, bucket, path)}
    end
  end

  @doc """
  Executes an ExAws operation, respecting the `s3_enabled` config.

  Returns `{:ok, %{}}` when S3 is disabled (test environment).
  """
  @spec request(ExAws.Operation.t()) :: {:ok, term()} | {:error, term()}
  def request(operation) do
    if s3_enabled?() do
      ExAws.request(operation)
    else
      # Return mock success in test environment
      # Structure works for both list ops (need body.contents) and mutate ops (just check {:ok, _})
      {:ok, %{body: %{contents: [], is_truncated: false}}}
    end
  end

  defp s3_enabled? do
    Application.get_env(:gallformers, :s3_enabled, true)
  end

  defp mock_presigned_url(http_method, bucket, path) do
    encoded_bucket = URI.encode(bucket)
    encoded_path = encode_path(path)
    method = http_method |> to_string() |> String.upcase()

    "https://example.test/mock-s3/#{encoded_bucket}/#{encoded_path}?method=#{method}"
  end

  defp encode_path(path) do
    path
    |> String.trim_leading("/")
    |> String.split("/", trim: true)
    |> Enum.map_join("/", &URI.encode/1)
  end
end
