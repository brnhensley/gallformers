defmodule Gallformers.Repo.Migrations.CreateSpeciesFts do
  @moduledoc """
  Creates FTS5 full-text search virtual table for species.

  The species_fts table indexes species names and their aliases for fast
  prefix matching and relevance-ranked search using bm25().
  """
  use Ecto.Migration

  def up do
    # Create FTS5 virtual table for species search
    # - species_id stored for easy joins (not indexed for search)
    # - porter tokenizer provides stemming (searching -> search)
    # - unicode61 handles international characters
    # - prefix='2 3' enables 2 and 3 character prefix searches
    execute("""
    CREATE VIRTUAL TABLE IF NOT EXISTS species_fts USING fts5(
      species_id UNINDEXED,
      name,
      aliases,
      tokenize='porter unicode61',
      prefix='2 3'
    )
    """)

    # Populate initial data from species and their aliases
    # Only run if the species table exists (may not exist in test environment)
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
  end

  def down do
    execute("DROP TABLE IF EXISTS species_fts")
  end

  defp species_table_exists? do
    result =
      repo().query!("SELECT name FROM sqlite_master WHERE type='table' AND name='species'")

    length(result.rows) > 0
  end
end
