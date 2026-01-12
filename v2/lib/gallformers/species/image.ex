defmodule Gallformers.Species.Image do
  @moduledoc """
  Ecto schema for the image table.

  Images are associated with species and stored on S3/CloudFront.
  """
  use Ecto.Schema

  # CloudFront base URL for images
  @image_base_url "https://dhz6u1p7t6okk.cloudfront.net"

  @type t :: %__MODULE__{
          id: integer() | nil,
          species_id: integer() | nil,
          source_id: integer() | nil,
          path: String.t() | nil,
          default: boolean(),
          creator: String.t() | nil,
          attribution: String.t() | nil,
          license: String.t() | nil,
          licenselink: String.t() | nil,
          sourcelink: String.t() | nil,
          uploader: String.t() | nil,
          lastchangedby: String.t() | nil,
          caption: String.t() | nil
        }

  schema "image" do
    field :path, :string
    field :default, :boolean, default: false
    field :creator, :string
    field :attribution, :string
    field :license, :string
    field :licenselink, :string
    field :sourcelink, :string
    field :uploader, :string
    field :lastchangedby, :string
    field :caption, :string

    belongs_to :species, Gallformers.Species.Species
    belongs_to :source, Gallformers.Sources.Source
  end

  @doc """
  Returns the full CloudFront URL for an image.
  """
  @spec url(t()) :: String.t()
  def url(%__MODULE__{path: path}) when is_binary(path) do
    @image_base_url <> "/" <> path
  end

  def url(_), do: nil

  @doc """
  Returns the CloudFront base URL.
  """
  @spec base_url() :: String.t()
  def base_url, do: @image_base_url
end
