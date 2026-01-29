defmodule Gallformers.Repo.Migrations.CreatePageViews do
  use Gallformers.Migration

  def change do
    create table(:page_views) do
      add :path, :string, null: false
      add :referrer_host, :string
      add :browser, :string
      add :device_type, :string
      add :visitor_hash, :string, null: false

      timestamps(updated_at: false)
    end

    create index(:page_views, [:inserted_at])
    create index(:page_views, [:path])
    create index(:page_views, [:visitor_hash, :inserted_at])
  end
end
