defmodule Gallformers.ArticlesTest do
  @moduledoc """
  Unit tests for the Articles context.
  """
  use Gallformers.DataCase, async: true

  alias Gallformers.Articles
  alias Gallformers.Articles.Article

  @valid_attrs %{
    title: "Test Article",
    author: "Test Author",
    content: "This is the article content."
  }

  @update_attrs %{
    title: "Updated Title",
    author: "Updated Author",
    content: "Updated content."
  }

  @invalid_attrs %{title: nil, author: nil, content: nil}

  defp create_article(attrs \\ %{}) do
    {:ok, article} = Articles.create_article(Map.merge(@valid_attrs, attrs))
    article
  end

  describe "list_articles/1" do
    test "returns empty list when no articles exist" do
      assert Articles.list_articles() == []
    end

    test "returns all articles" do
      article = create_article()
      assert [returned] = Articles.list_articles()
      assert returned.id == article.id
    end

    test "filters by published_only option" do
      _unpublished = create_article(%{title: "Unpublished"})
      published = create_article(%{title: "Published", is_published: true})

      assert [returned] = Articles.list_articles(published_only: true)
      assert returned.id == published.id
    end

    test "filters by tag" do
      _untagged = create_article(%{title: "Untagged"})
      tagged = create_article(%{title: "Tagged", tags: ["biology", "ecology"]})

      assert [returned] = Articles.list_articles(tag: "biology")
      assert returned.id == tagged.id
    end
  end

  describe "list_published_articles/0" do
    test "returns only published articles" do
      _unpublished = create_article(%{title: "Unpublished"})
      published = create_article(%{title: "Published", is_published: true})

      assert [returned] = Articles.list_published_articles()
      assert returned.id == published.id
    end
  end

  describe "get_article!/1" do
    test "returns article with given id" do
      article = create_article()
      assert Articles.get_article!(article.id).id == article.id
    end

    test "raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Articles.get_article!(999_999)
      end
    end
  end

  describe "get_article_by_slug!/1" do
    test "returns article with given slug" do
      article = create_article()
      assert Articles.get_article_by_slug!(article.slug).id == article.id
    end

    test "raises for non-existent slug" do
      assert_raise Ecto.NoResultsError, fn ->
        Articles.get_article_by_slug!("nonexistent-slug")
      end
    end
  end

  describe "get_article_by_slug/1" do
    test "returns article with given slug" do
      article = create_article()
      assert Articles.get_article_by_slug(article.slug).id == article.id
    end

    test "returns nil for non-existent slug" do
      assert Articles.get_article_by_slug("nonexistent-slug") == nil
    end
  end

  describe "create_article/1" do
    test "creates article with valid data" do
      assert {:ok, %Article{} = article} = Articles.create_article(@valid_attrs)
      assert article.title == "Test Article"
      assert article.author == "Test Author"
      assert article.content == "This is the article content."
      assert article.is_published == false
      assert article.tags == []
    end

    test "auto-generates slug from title" do
      assert {:ok, %Article{} = article} = Articles.create_article(@valid_attrs)
      assert article.slug == "test-article"
    end

    test "uses provided slug if given" do
      attrs = Map.put(@valid_attrs, :slug, "custom-slug")
      assert {:ok, %Article{} = article} = Articles.create_article(attrs)
      assert article.slug == "custom-slug"
    end

    test "returns error with invalid data" do
      assert {:error, %Ecto.Changeset{}} = Articles.create_article(@invalid_attrs)
    end

    test "enforces unique slug" do
      assert {:ok, _} = Articles.create_article(@valid_attrs)
      assert {:error, changeset} = Articles.create_article(@valid_attrs)
      assert "has already been taken" in errors_on(changeset).slug
    end

    test "stores tags as array" do
      attrs = Map.put(@valid_attrs, :tags, ["biology", "ecology"])
      assert {:ok, %Article{} = article} = Articles.create_article(attrs)
      assert article.tags == ["biology", "ecology"]
    end
  end

  describe "update_article/2" do
    test "updates article with valid data" do
      article = create_article()
      assert {:ok, %Article{} = updated} = Articles.update_article(article, @update_attrs)
      assert updated.title == "Updated Title"
      assert updated.author == "Updated Author"
      assert updated.content == "Updated content."
    end

    test "returns error with invalid data" do
      article = create_article()
      assert {:error, %Ecto.Changeset{}} = Articles.update_article(article, @invalid_attrs)
    end
  end

  describe "delete_article/1" do
    test "deletes the article" do
      article = create_article()
      assert {:ok, %Article{}} = Articles.delete_article(article)
      assert_raise Ecto.NoResultsError, fn -> Articles.get_article!(article.id) end
    end
  end

  describe "change_article/2" do
    test "returns a changeset" do
      article = create_article()
      assert %Ecto.Changeset{} = Articles.change_article(article)
    end
  end

  describe "list_related_articles/2" do
    test "returns empty list when article has no tags" do
      article = create_article(%{tags: []})
      assert Articles.list_related_articles(article) == []
    end

    test "returns articles with shared tags" do
      article1 = create_article(%{title: "Article 1", tags: ["biology"], is_published: true})
      article2 = create_article(%{title: "Article 2", tags: ["biology", "ecology"], is_published: true})
      _article3 = create_article(%{title: "Article 3", tags: ["botany"], is_published: true})

      related = Articles.list_related_articles(article1)
      assert length(related) == 1
      assert hd(related).id == article2.id
    end

    test "excludes the article itself" do
      article = create_article(%{title: "Article 1", tags: ["biology"], is_published: true})
      _article2 = create_article(%{title: "Article 2", tags: ["biology"], is_published: true})

      related = Articles.list_related_articles(article)
      refute Enum.any?(related, &(&1.id == article.id))
    end

    test "only returns published articles" do
      article = create_article(%{title: "Article 1", tags: ["biology"], is_published: true})
      _unpublished = create_article(%{title: "Unpublished", tags: ["biology"], is_published: false})

      related = Articles.list_related_articles(article)
      assert related == []
    end

    test "respects limit option" do
      article = create_article(%{title: "Article 1", tags: ["biology"], is_published: true})
      for i <- 2..10 do
        create_article(%{title: "Article #{i}", tags: ["biology"], is_published: true})
      end

      related = Articles.list_related_articles(article, limit: 3)
      assert length(related) == 3
    end
  end

  describe "list_tags/0" do
    test "returns empty list when no articles exist" do
      assert Articles.list_tags() == []
    end

    test "returns tags with counts" do
      create_article(%{title: "Article 1", tags: ["biology", "ecology"]})
      create_article(%{title: "Article 2", tags: ["biology", "botany"]})

      tags = Articles.list_tags()
      biology = Enum.find(tags, &(&1.tag == "biology"))
      ecology = Enum.find(tags, &(&1.tag == "ecology"))
      botany = Enum.find(tags, &(&1.tag == "botany"))

      assert biology.count == 2
      assert ecology.count == 1
      assert botany.count == 1
    end
  end

  describe "Article.slugify/1" do
    test "converts to lowercase" do
      assert Article.slugify("Hello World") == "hello-world"
    end

    test "replaces spaces with hyphens" do
      assert Article.slugify("one two three") == "one-two-three"
    end

    test "removes special characters" do
      assert Article.slugify("Hello! World?") == "hello-world"
    end

    test "handles ampersands" do
      assert Article.slugify("Oaks & Their Galls") == "oaks-their-galls"
    end

    test "collapses multiple hyphens" do
      assert Article.slugify("hello   world") == "hello-world"
    end

    test "trims leading and trailing hyphens" do
      assert Article.slugify("  hello world  ") == "hello-world"
    end
  end
end
