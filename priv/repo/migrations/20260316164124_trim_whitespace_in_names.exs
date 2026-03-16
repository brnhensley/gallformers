defmodule Gallformers.Repo.Migrations.TrimWhitespaceInNames do
  use Ecto.Migration

  def up do
    # Trim leading/trailing whitespace from key string fields.
    # This fixes gall 6107 (" Synchytrium tillaeae") and prevents similar issues.
    execute "UPDATE species SET name = BTRIM(name) WHERE name != BTRIM(name)"
    execute "UPDATE alias SET name = BTRIM(name) WHERE name != BTRIM(name)"
    execute "UPDATE taxonomy SET name = BTRIM(name) WHERE name != BTRIM(name)"
    execute "UPDATE source SET title = BTRIM(title) WHERE title != BTRIM(title)"
    execute "UPDATE source SET author = BTRIM(author) WHERE author != BTRIM(author)"
  end

  def down do
    # Data migration — not reversible
    :ok
  end
end
