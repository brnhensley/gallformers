defmodule Gallformers.Repo.Migrations.AddNotNullToHostForeignKeys do
  @moduledoc """
  Adds NOT NULL constraints to host table foreign keys.

  The Host schema validates these as required fields, but the database
  previously allowed NULLs. This migration enforces data integrity at
  the database level.

  SQLite requires table recreation to add NOT NULL constraints.
  """
  use Ecto.Migration

  def up do
    # SQLite doesn't support ALTER COLUMN, so we recreate the table
    execute("""
    CREATE TABLE host_new (
      id INTEGER PRIMARY KEY NOT NULL,
      host_species_id INTEGER NOT NULL,
      gall_species_id INTEGER NOT NULL,
      FOREIGN KEY (host_species_id) REFERENCES species (id) ON DELETE CASCADE,
      FOREIGN KEY (gall_species_id) REFERENCES species (id) ON DELETE CASCADE
    )
    """)

    execute("INSERT INTO host_new SELECT * FROM host")
    execute("DROP TABLE host")
    execute("ALTER TABLE host_new RENAME TO host")
  end

  def down do
    # Reverse: recreate table without NOT NULL constraints
    execute("""
    CREATE TABLE host_new (
      id INTEGER PRIMARY KEY NOT NULL,
      host_species_id INTEGER,
      gall_species_id INTEGER,
      FOREIGN KEY (host_species_id) REFERENCES species (id) ON DELETE CASCADE,
      FOREIGN KEY (gall_species_id) REFERENCES species (id) ON DELETE CASCADE
    )
    """)

    execute("INSERT INTO host_new SELECT * FROM host")
    execute("DROP TABLE host")
    execute("ALTER TABLE host_new RENAME TO host")
  end
end
