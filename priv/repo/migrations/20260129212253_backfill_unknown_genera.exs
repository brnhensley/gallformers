defmodule Gallformers.Repo.Migrations.BackfillUnknownGenera do
  use Gallformers.Migration

  @doc """
  Creates an "Unknown" genus for every family that doesn't already have one.

  Unknown genera are placeholders for undescribed species where the genus
  is not yet known. Each family should have exactly one Unknown genus.
  """
  def up do
    # Insert Unknown genus for each family that doesn't have one
    execute("""
    INSERT INTO taxonomy (name, description, type, parent_id)
    SELECT
      'Unknown',
      'Placeholder genus for undescribed species',
      'genus',
      f.id
    FROM taxonomy f
    WHERE f.type = 'family'
      AND NOT EXISTS (
        SELECT 1 FROM taxonomy g
        WHERE g.type = 'genus'
          AND g.name = 'Unknown'
          AND g.parent_id = f.id
      )
    """)
  end

  def down do
    # Remove Unknown genera that have no species linked to them
    # (preserves any that are actually in use)
    execute("""
    DELETE FROM taxonomy
    WHERE type = 'genus'
      AND name = 'Unknown'
      AND description = 'Placeholder genus for undescribed species'
      AND id NOT IN (
        SELECT DISTINCT taxonomy_id FROM speciestaxonomy
      )
    """)
  end
end
