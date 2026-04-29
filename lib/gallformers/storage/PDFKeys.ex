defmodule Gallformers.Storage.PDFKeys do
  @moduledoc """
  Storage helpers for PDF keys.
  """

  alias Gallformers.Keys.Key
  alias Gallformers.Storage.S3

  @type variant :: :text_only | :with_images

  @doc """
  Returns the full CDN URLs for a key's files.
  """
  @spec public_urls(Key.t()) :: %{text_only: String.t(), with_images: String.t()}
  def public_urls(key) do
    %{
      text_only: public_url(path(key, :text_only)),
      with_images: public_url(path(key, :with_images))
    }
  end

  @doc """
  Uploads a PDF file for a given key and variant.
  """
  @spec upload_pdf(Key.t(), variant(), binary()) :: :ok | {:error, term()}
  def upload_pdf(key, variant, pdf_data) do
    with {:ok, _response} <-
           ExAws.S3.put_object(public_bucket(), path(key, variant), pdf_data,
             content_type: "application/pdf"
           )
           |> S3.request() do
      :ok
    end
  end

  defp public_url(path) do
    base_url = Application.get_env(:gallformers, :images)[:cdn_url]
    "#{base_url}/#{path}"
  end

  defp public_bucket do
    Application.get_env(:gallformers, :images)[:bucket]
  end

  defp path(key, :text_only) do
    "keys/#{key.slug}/#{key.slug}.pdf"
  end

  defp path(key, :with_images) do
    "keys/#{key.slug}/#{key.slug}-images.pdf"
  end
end
