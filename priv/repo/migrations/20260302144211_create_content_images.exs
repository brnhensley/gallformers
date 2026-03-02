defmodule Gallformers.Repo.Migrations.CreateContentImages do
  use Gallformers.Migration

  def change do
    create table(:content_images) do
      add :path, :text, null: false
      add :sort_order, :integer, null: false, default: 0
      add :creator, :text
      add :attribution, :text
      add :license, :text
      add :licenselink, :text
      add :sourcelink, :text
      add :caption, :text
      add :uploader, :text
      add :lastchangedby, :text

      add :article_id, references(:articles, on_delete: :delete_all)
      add :key_id, references(:keys, on_delete: :delete_all)
      add :source_id, references(:source, on_delete: :nilify_all)

      timestamps()
    end

    create unique_index(:content_images, [:path])
    create index(:content_images, [:article_id, :sort_order])
    create index(:content_images, [:key_id, :sort_order])

    # Exactly one owner: either article_id or key_id must be set, not both
    execute(
      "CREATE TRIGGER content_images_exactly_one_owner_insert
       BEFORE INSERT ON content_images
       BEGIN
         SELECT CASE
           WHEN (NEW.article_id IS NOT NULL AND NEW.key_id IS NOT NULL)
             OR (NEW.article_id IS NULL AND NEW.key_id IS NULL)
         THEN RAISE(ABORT, 'content_images must have exactly one owner (article_id or key_id)')
         END;
       END;",
      "DROP TRIGGER IF EXISTS content_images_exactly_one_owner_insert;"
    )

    execute(
      "CREATE TRIGGER content_images_exactly_one_owner_update
       BEFORE UPDATE ON content_images
       BEGIN
         SELECT CASE
           WHEN (NEW.article_id IS NOT NULL AND NEW.key_id IS NOT NULL)
             OR (NEW.article_id IS NULL AND NEW.key_id IS NULL)
         THEN RAISE(ABORT, 'content_images must have exactly one owner (article_id or key_id)')
         END;
       END;",
      "DROP TRIGGER IF EXISTS content_images_exactly_one_owner_update;"
    )
  end
end
