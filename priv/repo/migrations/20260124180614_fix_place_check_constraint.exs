defmodule Gallformers.Repo.Migrations.FixPlaceCheckConstraint do
  use Gallformers.Migration

  @moduledoc """
  Fixes the place table's CHECK constraint syntax inherited from V1 database.

  The V1 database used double quotes (column identifiers) instead of single
  quotes (string literals) in the CHECK constraint:

    CHECK (type IN ("continent", ...))  -- Wrong: "continent" = column name
    CHECK (type IN ('continent', ...))  -- Correct: 'continent' = string literal

  This worked in V1 because the FK pragma was never enabled. In V2, migrations
  that enable `PRAGMA foreign_keys = ON` cause SQLite to validate ALL constraints,
  exposing this latent bug.

  SQLite requires table recreation to change CHECK constraints.
  """

  def up do
    # All statements in single execute to keep PRAGMA in same connection context
    execute("""
    PRAGMA foreign_keys = OFF;
    CREATE TABLE place_new (
      id INTEGER PRIMARY KEY NOT NULL,
      name TEXT UNIQUE NOT NULL,
      code TEXT NOT NULL,
      type TEXT NOT NULL CHECK (type IN ('continent', 'country', 'region', 'state', 'province', 'county', 'city'))
    );
    INSERT INTO place_new SELECT * FROM place;
    DROP TABLE place;
    ALTER TABLE place_new RENAME TO place;
    PRAGMA foreign_keys = ON;
    """)
  end

  def down do
    # All statements in single execute to keep PRAGMA in same connection context
    execute("""
    PRAGMA foreign_keys = OFF;
    CREATE TABLE place_new (
      id INTEGER PRIMARY KEY NOT NULL,
      name TEXT UNIQUE NOT NULL,
      code TEXT NOT NULL,
      type TEXT NOT NULL CHECK (type IN ("continent", "country", "region", "state", "province", "county", "city"))
    );
    INSERT INTO place_new SELECT * FROM place;
    DROP TABLE place;
    ALTER TABLE place_new RENAME TO place;
    PRAGMA foreign_keys = ON;
    """)
  end
end
