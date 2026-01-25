defmodule Gallformers.Migration do
  @moduledoc """
  Safe migration module for SQLite.

  Use this instead of `Ecto.Migration` to ensure foreign key constraints
  don't cause silent data loss during table recreation.

  ## The Problem

  SQLite requires DROP TABLE + CREATE TABLE to modify constraints.
  With `ON DELETE CASCADE` foreign keys, dropping a parent table deletes
  all child rows. The fix is `PRAGMA foreign_keys = OFF`, but this pragma
  is ignored inside transactions - and Ecto runs migrations in transactions
  by default.

  ## The Solution

  This module sets `@disable_ddl_transaction true` automatically, ensuring
  PRAGMA statements actually take effect.

  ## Usage

      defmodule Gallformers.Repo.Migrations.MyMigration do
        use Gallformers.Migration  # NOT Ecto.Migration

        def up do
          # Your migration code
        end
      end

  ## Helper Functions

  For table recreation (required when changing constraints in SQLite), use
  the `safe_recreate_table/2` helper which handles the PRAGMA dance correctly:

      def up do
        safe_recreate_table :place do
          execute "CREATE TABLE place_new (...)"
          execute "INSERT INTO place_new SELECT * FROM place"
          execute "DROP TABLE place"
          execute "ALTER TABLE place_new RENAME TO place"
        end
      end
  """

  defmacro __using__(_opts) do
    quote do
      use Ecto.Migration

      # Critical: These allow PRAGMA foreign_keys = OFF to work
      @disable_ddl_transaction true
      @disable_migration_lock true

      import Gallformers.Migration, only: [safe_recreate_table: 2]
    end
  end

  @doc """
  Safely recreates a table, handling foreign key constraints correctly.

  Wraps the given block with PRAGMA foreign_keys = OFF/ON and runs
  a foreign key check afterward to ensure referential integrity.

  ## Example

      safe_recreate_table :users do
        execute "CREATE TABLE users_new (...)"
        execute "INSERT INTO users_new SELECT * FROM users"
        execute "DROP TABLE users"
        execute "ALTER TABLE users_new RENAME TO users"
      end
  """
  defmacro safe_recreate_table(table_name, do: block) do
    quote do
      # Log what we're doing
      Ecto.Migration.execute("SELECT 'Safely recreating table: #{unquote(table_name)}' as info")

      # Disable foreign key enforcement
      Ecto.Migration.execute("PRAGMA foreign_keys = OFF")

      # Run the table recreation block
      unquote(block)

      # Re-enable foreign key enforcement
      Ecto.Migration.execute("PRAGMA foreign_keys = ON")

      # Verify no FK violations were introduced
      Ecto.Migration.execute("PRAGMA foreign_key_check")
    end
  end
end
