defmodule Gallformers.Storage do
  @moduledoc """
  Storage-layer umbrella namespace.

  This module retains only shared public-storage configuration and the generic
  public-bucket upload helper used across storage submodules.
  """
  use Boundary, deps: [Gallformers.Async], exports: :all

  alias Gallformers.Storage.S3

  @doc """
  Returns the CDN base URL for the public image bucket.
  """
  @spec cdn_url() :: String.t()
  def cdn_url do
    Application.get_env(:gallformers, :images)[:cdn_url]
  end

  @doc """
  Returns the S3 bucket name for public image and PDF assets.
  """
  @spec bucket() :: String.t()
  def bucket do
    Application.get_env(:gallformers, :images)[:bucket]
  end

  @doc """
  Returns the S3 image prefix for preview deploys.
  """
  @spec s3_image_prefix() :: String.t() | nil
  def s3_image_prefix do
    Application.get_env(:gallformers, :s3_image_prefix)
  end

  @doc """
  Uploads data to the public storage bucket.
  """
  @spec upload(String.t(), binary(), String.t()) :: {:ok, term()} | {:error, term()}
  def upload(path, data, content_type) do
    ExAws.S3.put_object(bucket(), path, data, content_type: content_type)
    |> S3.request()
  end
end
