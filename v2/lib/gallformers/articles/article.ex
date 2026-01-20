defmodule Gallformers.Articles.Article do
  @moduledoc """
  Ecto schema for the articles table.

  Represents a reference article with markdown content, free-form tags,
  and publication status.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          slug: String.t() | nil,
          title: String.t() | nil,
          author: String.t() | nil,
          description: String.t() | nil,
          content: String.t() | nil,
          tags: [String.t()],
          is_published: boolean(),
          published_at: DateTime.t() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "articles" do
    field :slug, :string
    field :title, :string
    field :author, :string
    field :description, :string
    field :content, :string
    field :tags, Gallformers.Articles.TagsType, default: []
    field :is_published, :boolean, default: false
    field :published_at, :utc_datetime

    # Virtual field for form handling
    field :tags_input, :string, virtual: true

    timestamps()
  end

  @doc """
  Creates a changeset for an article.

  Automatically generates a slug from the title if not provided.
  """
  def changeset(article, attrs) do
    article
    |> cast(attrs, [:slug, :title, :author, :description, :content, :tags, :is_published])
    |> validate_required([:title, :author, :content])
    |> maybe_generate_slug()
    |> validate_required([:slug])
    |> validate_length(:title, min: 1, max: 200)
    |> validate_length(:slug, min: 1, max: 200)
    |> unique_constraint(:slug)
  end

  defp maybe_generate_slug(changeset) do
    case get_field(changeset, :slug) do
      nil ->
        case get_change(changeset, :title) do
          nil -> changeset
          title -> put_change(changeset, :slug, slugify(title))
        end

      "" ->
        case get_field(changeset, :title) do
          nil -> changeset
          title -> put_change(changeset, :slug, slugify(title))
        end

      _slug ->
        changeset
    end
  end

  @doc """
  Converts a string to a URL-friendly slug.

  ## Examples

      iex> slugify("Hello World!")
      "hello-world"

      iex> slugify("Oaks & Their Galls")
      "oaks-their-galls"
  """
  @spec slugify(String.t()) :: String.t()
  def slugify(string) when is_binary(string) do
    string
    |> String.downcase()
    |> String.replace(~r/[^\w\s-]/u, "")
    |> String.replace(~r/[\s_]+/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
  end

  def slugify(_), do: ""
end
