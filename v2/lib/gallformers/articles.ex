defmodule Gallformers.Articles do
  @moduledoc """
  The Articles context.

  Provides functions for working with reference articles including
  listing, creating, updating, and searching by tags.
  """

  import Ecto.Query
  alias Gallformers.Articles.Article
  alias Gallformers.Repo

  @doc """
  Returns all articles, optionally filtered.

  ## Options

    * `:published_only` - if true, only returns published articles (default: false)
    * `:tag` - filter by a specific tag

  """
  @spec list_articles(keyword()) :: [Article.t()]
  def list_articles(opts \\ []) do
    published_only = Keyword.get(opts, :published_only, false)
    tag = Keyword.get(opts, :tag)

    Article
    |> maybe_filter_published(published_only)
    |> maybe_filter_by_tag(tag)
    |> order_by([a], desc: a.inserted_at)
    |> Repo.all()
  end

  defp maybe_filter_published(query, true) do
    where(query, [a], a.is_published == true)
  end

  defp maybe_filter_published(query, _), do: query

  defp maybe_filter_by_tag(query, nil), do: query
  defp maybe_filter_by_tag(query, ""), do: query

  defp maybe_filter_by_tag(query, tag) do
    # Use SQLite JSON functions for exact tag matching
    where(query, [a], fragment("EXISTS (SELECT 1 FROM json_each(?) WHERE value = ?)", a.tags, ^tag))
  end

  @doc """
  Returns all published articles ordered by date (newest first).
  """
  @spec list_published_articles() :: [Article.t()]
  def list_published_articles do
    list_articles(published_only: true)
  end

  @doc """
  Gets an article by ID.

  Raises `Ecto.NoResultsError` if not found.
  """
  @spec get_article!(integer()) :: Article.t()
  def get_article!(id) do
    Repo.get!(Article, id)
  end

  @doc """
  Gets an article by slug.

  Raises `Ecto.NoResultsError` if not found.
  """
  @spec get_article_by_slug!(String.t()) :: Article.t()
  def get_article_by_slug!(slug) do
    Repo.get_by!(Article, slug: slug)
  end

  @doc """
  Gets an article by slug, returning nil if not found.
  """
  @spec get_article_by_slug(String.t()) :: Article.t() | nil
  def get_article_by_slug(slug) do
    Repo.get_by(Article, slug: slug)
  end

  @doc """
  Creates an article.
  """
  @spec create_article(map()) :: {:ok, Article.t()} | {:error, Ecto.Changeset.t()}
  def create_article(attrs \\ %{}) do
    %Article{}
    |> Article.changeset(attrs)
    |> Repo.insert()
    |> broadcast(:article_created)
  end

  @doc """
  Updates an article.
  """
  @spec update_article(Article.t(), map()) :: {:ok, Article.t()} | {:error, Ecto.Changeset.t()}
  def update_article(%Article{} = article, attrs) do
    article
    |> Article.changeset(attrs)
    |> Repo.update()
    |> broadcast(:article_updated)
  end

  @doc """
  Deletes an article.
  """
  @spec delete_article(Article.t()) :: {:ok, Article.t()} | {:error, Ecto.Changeset.t()}
  def delete_article(%Article{} = article) do
    Repo.delete(article)
    |> broadcast(:article_deleted)
  end

  @doc """
  Returns a changeset for tracking article changes.
  """
  @spec change_article(Article.t(), map()) :: Ecto.Changeset.t()
  def change_article(%Article{} = article, attrs \\ %{}) do
    Article.changeset(article, attrs)
  end

  @doc """
  Returns articles related to the given article by shared tags.

  Finds published articles that share at least one tag with the given article,
  excluding the article itself. Results are ordered by most recent first.

  ## Options

    * `:limit` - maximum number of articles to return (default: 5)

  """
  @spec list_related_articles(Article.t(), keyword()) :: [Article.t()]
  def list_related_articles(%Article{} = article, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)

    if article.tags == [] do
      []
    else
      tags_json = Jason.encode!(article.tags)

      from(a in Article,
        where: a.id != ^article.id and a.is_published == true,
        where:
          fragment(
            "EXISTS (SELECT 1 FROM json_each(?) WHERE value IN (SELECT value FROM json_each(?)))",
            a.tags,
            ^tags_json
          ),
        order_by: [desc: a.inserted_at],
        limit: ^limit
      )
      |> Repo.all()
    end
  end

  @doc """
  Returns all unique tags with their counts.

  Returns a list of maps: `[%{tag: "biology", count: 3}, ...]`
  """
  @spec list_tags() :: [%{tag: String.t(), count: integer()}]
  def list_tags do
    articles = Repo.all(from(a in Article, select: a.tags))

    articles
    |> Enum.flat_map(fn tags -> tags || [] end)
    |> Enum.frequencies()
    |> Enum.map(fn {tag, count} -> %{tag: tag, count: count} end)
    |> Enum.sort_by(& &1.tag)
  end

  defp broadcast({:ok, article}, event) do
    Phoenix.PubSub.broadcast(Gallformers.PubSub, "articles", {event, article})
    {:ok, article}
  end

  defp broadcast({:error, changeset}, _event) do
    {:error, changeset}
  end
end
