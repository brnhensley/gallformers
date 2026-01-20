defmodule Gallformers.Repo.Migrations.AddAboutMeToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :about_me, :text
    end
  end
end
