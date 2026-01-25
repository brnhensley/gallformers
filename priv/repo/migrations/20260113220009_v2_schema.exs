defmodule Gallformers.Repo.Migrations.V2Schema do
  @moduledoc """
  Combined V2 schema migration for one-time V1 to V2 migration.
  Creates all new tables and columns needed for V2.
  """
  use Gallformers.Migration

  def up do
    # --- Species FTS ---
    execute("""
    CREATE VIRTUAL TABLE IF NOT EXISTS species_fts USING fts5(
      species_id UNINDEXED,
      name,
      aliases,
      tokenize='porter unicode61',
      prefix='2 3'
    )
    """)

    if species_table_exists?() do
      execute("""
      INSERT INTO species_fts(species_id, name, aliases)
      SELECT
        s.id,
        s.name,
        COALESCE(GROUP_CONCAT(a.name, ' '), '')
      FROM species s
      LEFT JOIN aliasspecies als ON als.species_id = s.id
      LEFT JOIN alias a ON a.id = als.alias_id
      GROUP BY s.id
      """)
    end

    # --- Articles table ---
    create table(:articles) do
      add :slug, :string, null: false
      add :title, :string, null: false
      add :author, :string, null: false
      add :content, :text, null: false
      add :tags, :string
      add :is_published, :boolean, default: false, null: false
      add :description, :text
      add :published_at, :utc_datetime

      timestamps()
    end

    create unique_index(:articles, [:slug])
    create index(:articles, [:is_published])

    # --- Users table ---
    create table(:users) do
      add :auth0_id, :text, null: false
      add :display_name, :text
      add :nickname, :text
      add :inaturalist_url, :text
      add :social_url, :text
      add :personal_url, :text
      add :show_on_about, :boolean, default: false, null: false
      add :about_me, :text

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:users, [:auth0_id])

    # --- Image sort_order ---
    # Only alter if image table exists (won't exist in fresh test DB)
    if image_table_exists?() do
      alter table(:image) do
        add :sort_order, :integer, default: 0, null: false
      end

      create index(:image, [:species_id, :sort_order])

      execute("""
      UPDATE image
      SET sort_order = (
        SELECT row_num FROM (
          SELECT
            i.id,
            ROW_NUMBER() OVER (
              PARTITION BY i.species_id
              ORDER BY i."default" DESC, COALESCE(s.title, ''), i.id ASC
            ) - 1 as row_num
          FROM image i
          LEFT JOIN source s ON i.source_id = s.id
        ) ranked
        WHERE ranked.id = image.id
      )
      """)
    end
  end

  def down do
    if image_table_exists?() do
      drop index(:image, [:species_id, :sort_order])

      alter table(:image) do
        remove :sort_order
      end
    end

    drop table(:users)
    drop table(:articles)
    execute("DROP TABLE IF EXISTS species_fts")
  end

  defp species_table_exists? do
    result =
      repo().query!("SELECT name FROM sqlite_master WHERE type='table' AND name='species'")

    length(result.rows) > 0
  end

  defp image_table_exists? do
    result =
      repo().query!("SELECT name FROM sqlite_master WHERE type='table' AND name='image'")

    length(result.rows) > 0
  end
end
