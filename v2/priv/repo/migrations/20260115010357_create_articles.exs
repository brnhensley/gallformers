defmodule Gallformers.Repo.Migrations.CreateArticles do
  @moduledoc """
  Creates the articles table for database-backed reference articles.

  Articles store markdown content with free-form tags (JSON array) and
  publication status for the reference section of the site.
  """
  use Ecto.Migration

  def change do
    create table(:articles) do
      add :slug, :string, null: false
      add :title, :string, null: false
      add :author, :string, null: false
      add :content, :text, null: false
      add :tags, :string
      add :is_published, :boolean, default: false, null: false

      timestamps()
    end

    create unique_index(:articles, [:slug])
    create index(:articles, [:is_published])
  end
end
