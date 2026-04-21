defmodule Gallformers.Repo.Migrations.AddObanJobs do
  use Ecto.Migration

  def up do
    # Initial install: create the complete Oban schema.
    Oban.Migrations.up()

    execute("ALTER TABLE oban_jobs SET (autovacuum_vacuum_scale_factor = 0.01)")
  end

  def down do
    # Initial install rollback: remove the complete Oban schema.
    #
    # Future Oban upgrades must use separate versioned migrations, e.g.
    # `Oban.Migrations.up(version: N)` / `Oban.Migrations.down(version: N)`,
    # so rolling back an incremental upgrade doesn't drop `oban_jobs`.
    Oban.Migrations.down()
  end
end
