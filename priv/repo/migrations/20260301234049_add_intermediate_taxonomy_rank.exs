defmodule Gallformers.Repo.Migrations.AddIntermediateTaxonomyRank do
  use Gallformers.Migration

  def change do
    alter table(:taxonomy) do
      add :rank, :string
    end
  end
end
