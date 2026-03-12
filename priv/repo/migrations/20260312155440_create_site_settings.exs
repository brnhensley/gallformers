defmodule Gallformers.Repo.Migrations.CreateSiteSettings do
  use Gallformers.Migration

  def change do
    create table(:site_settings) do
      add :key, :string, null: false
      add :value, :text

      timestamps()
    end

    create unique_index(:site_settings, [:key])
  end
end
