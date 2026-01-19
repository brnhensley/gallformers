defmodule Gallformers.Repo.Migrations.AddDescriptionAndPublishedAtToArticles do
  use Ecto.Migration

  def change do
    alter table(:articles) do
      add :description, :text
      add :published_at, :utc_datetime
    end

    # Backfill published_at for existing published articles
    execute(
      "UPDATE articles SET published_at = inserted_at WHERE is_published = 1",
      "UPDATE articles SET published_at = NULL"
    )
  end
end
