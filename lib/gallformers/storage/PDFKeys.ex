defmodule Gallformers.Storage.PDFKeys do
  @moduledoc """
  Storage helpers for PDF keys.
  """

  alias Gallformers.Keys.Key
  alias Gallformers.Storage

  @type variant :: :text_only | :with_images

  @doc """
  Returns the full CDN URLs for a key's files.
  """
  @spec public_urls(Key.t()) :: %{text_only: String.t(), with_images: String.t()}
  def public_urls(key) do
    cdn = Storage.cdn_url()

    %{
      text_only: "#{cdn}/#{path(key, :text_only)}",
      with_images: "#{cdn}/#{path(key, :with_images)}"
    }
  end

  @doc """
  Uploads a PDF file for a given key and variant.
  """
  @spec upload_pdf(Key.t(), variant(), binary()) :: :ok | {:error, term()}
  def upload_pdf(key, variant, pdf_data) do
    with {:ok, _response} <- Storage.upload(path(key, variant), pdf_data, "application/pdf") do
      :ok
    end
  end

  defp path(key, :text_only) do
    "keys/#{key.slug}/#{key.slug}.pdf"
  end

  defp path(key, :with_images) do
    "keys/#{key.slug}/#{key.slug}-images.pdf"
  end
end
