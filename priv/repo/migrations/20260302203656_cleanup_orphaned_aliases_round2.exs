defmodule Gallformers.Repo.Migrations.CleanupOrphanedAliasesRound2 do
  use Gallformers.Migration

  def up do
    # Delete orphaned alias records that have no alias_species or taxonomy_alias links.
    # Root cause: delete_gall/delete_host bypassed Species.delete_species, which owns
    # the orphan cleanup logic. Those functions have been removed — all deletes now go
    # through Species.delete_species.
    execute("""
    DELETE FROM alias
    WHERE id NOT IN (SELECT alias_id FROM alias_species)
      AND id NOT IN (SELECT alias_id FROM taxonomy_alias)
    """)
  end

  def down do
    # Data cleanup — not reversible
    :ok
  end
end
