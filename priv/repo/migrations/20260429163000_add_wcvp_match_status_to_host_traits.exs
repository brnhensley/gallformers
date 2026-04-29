defmodule Gallformers.Repo.Migrations.AddWcvpMatchStatusToHostTraits do
  use Ecto.Migration

  def change do
    alter table(:host_traits) do
      add :wcvp_match_status, :string
    end

    execute """
    ALTER TABLE host_traits
    ADD CONSTRAINT host_traits_wcvp_match_status_check
    CHECK (wcvp_match_status IN ('no_match', 'ignored'))
    """,
    """
    ALTER TABLE host_traits
    DROP CONSTRAINT IF EXISTS host_traits_wcvp_match_status_check
    """

    create index(:host_traits, [:wcvp_match_status])
  end
end
