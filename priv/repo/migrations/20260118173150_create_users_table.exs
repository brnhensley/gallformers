defmodule Gallformers.Repo.Migrations.CreateUsersTable do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :auth0_id, :text, null: false
      add :display_name, :text
      add :nickname, :text
      add :inaturalist_url, :text
      add :social_url, :text
      add :personal_url, :text
      add :show_on_about, :boolean, default: false, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:users, [:auth0_id])
  end
end
