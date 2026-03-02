defmodule Gallformers.ContentImages.ContentImage do
  @moduledoc """
  Schema for content images — images owned by articles or keys.

  Each image belongs to exactly one owner (article or key), enforced by both
  changeset validation and a database trigger.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @required_fields [:path]
  @optional_fields [
    :sort_order,
    :creator,
    :attribution,
    :license,
    :licenselink,
    :sourcelink,
    :caption,
    :uploader,
    :lastchangedby,
    :article_id,
    :key_id,
    :source_id
  ]

  schema "content_images" do
    field :path, :string
    field :sort_order, :integer, default: 0
    field :creator, :string
    field :attribution, :string
    field :license, :string
    field :licenselink, :string
    field :sourcelink, :string
    field :caption, :string
    field :uploader, :string
    field :lastchangedby, :string

    belongs_to :article, Gallformers.Articles.Article
    belongs_to :key, Gallformers.Keys.Key
    belongs_to :source, Gallformers.Sources.Source

    timestamps()
  end

  @doc """
  Changeset for creating a content image.
  """
  def changeset(content_image, attrs) do
    content_image
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_exactly_one_owner()
    |> unique_constraint(:path)
    |> foreign_key_constraint(:article_id)
    |> foreign_key_constraint(:key_id)
    |> foreign_key_constraint(:source_id)
  end

  defp validate_exactly_one_owner(changeset) do
    article_id = get_field(changeset, :article_id)
    key_id = get_field(changeset, :key_id)

    case {article_id, key_id} do
      {nil, nil} ->
        add_error(changeset, :article_id, "either article_id or key_id must be set")

      {_, nil} ->
        changeset

      {nil, _} ->
        changeset

      {_, _} ->
        add_error(changeset, :article_id, "cannot set both article_id and key_id")
    end
  end
end
