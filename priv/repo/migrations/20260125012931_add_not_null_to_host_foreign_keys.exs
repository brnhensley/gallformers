defmodule Gallformers.Repo.Migrations.AddNotNullToHostForeignKeys do
  @moduledoc """
  Adds NOT NULL constraints to host table foreign keys.

  The Host schema validates these as required fields, but the database
  previously allowed NULLs. This migration enforces data integrity at
  the database level.

  SQLite requires table recreation to add NOT NULL constraints.
  """
  use Gallformers.Migration

  def up do
    # All statements in single execute to keep PRAGMA in same connection context
    execute("""
    PRAGMA foreign_keys = OFF;
    CREATE TABLE host_new (
      id INTEGER PRIMARY KEY NOT NULL,
      host_species_id INTEGER NOT NULL,
      gall_species_id INTEGER NOT NULL,
      FOREIGN KEY (host_species_id) REFERENCES species (id) ON DELETE CASCADE,
      FOREIGN KEY (gall_species_id) REFERENCES species (id) ON DELETE CASCADE
    );
    INSERT INTO host_new SELECT * FROM host;
    DROP TABLE host;
    ALTER TABLE host_new RENAME TO host;
    PRAGMA foreign_keys = ON;
    """)
  end

  def down do
    # All statements in single execute to keep PRAGMA in same connection context
    execute("""
    PRAGMA foreign_keys = OFF;
    CREATE TABLE host_new (
      id INTEGER PRIMARY KEY NOT NULL,
      host_species_id INTEGER,
      gall_species_id INTEGER,
      FOREIGN KEY (host_species_id) REFERENCES species (id) ON DELETE CASCADE,
      FOREIGN KEY (gall_species_id) REFERENCES species (id) ON DELETE CASCADE
    );
    INSERT INTO host_new SELECT * FROM host;
    DROP TABLE host;
    ALTER TABLE host_new RENAME TO host;
    PRAGMA foreign_keys = ON;
    """)
  end
end
