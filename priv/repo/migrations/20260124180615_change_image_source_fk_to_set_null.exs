defmodule Gallformers.Repo.Migrations.ChangeImageSourceFkToSetNull do
  use Gallformers.Migration

  @moduledoc """
  Changes the image.source_id foreign key from ON DELETE CASCADE to ON DELETE SET NULL.

  Previously, deleting a source would cascade-delete any images attributed to it.
  Now, deleting a source will set the image's source_id to NULL, preserving the image.
  """

  def up do
    # All statements in single execute to keep PRAGMA in same connection context
    execute("""
    PRAGMA foreign_keys = OFF;
    CREATE TABLE image_new (
      id          INTEGER PRIMARY KEY NOT NULL,
      species_id  INTEGER NOT NULL,
      source_id   INTEGER,
      path        TEXT    UNIQUE NOT NULL,
      "default"   BOOLEAN DEFAULT FALSE,
      creator     TEXT,
      attribution TEXT,
      sourcelink  TEXT,
      license     TEXT,
      licenselink TEXT,
      uploader    TEXT,
      lastchangedby TEXT,
      caption     TEXT DEFAULT '',
      sort_order  INTEGER DEFAULT 0 NOT NULL,
      FOREIGN KEY (species_id) REFERENCES species (id) ON DELETE CASCADE,
      FOREIGN KEY (source_id) REFERENCES source (id) ON DELETE SET NULL
    );
    INSERT INTO image_new SELECT * FROM image;
    DROP TABLE image;
    ALTER TABLE image_new RENAME TO image;
    CREATE INDEX "image_species_id_sort_order_index" ON "image" ("species_id", "sort_order");
    PRAGMA foreign_keys = ON;
    """)
  end

  def down do
    # All statements in single execute to keep PRAGMA in same connection context
    execute("""
    PRAGMA foreign_keys = OFF;
    CREATE TABLE image_new (
      id          INTEGER PRIMARY KEY NOT NULL,
      species_id  INTEGER NOT NULL,
      source_id   INTEGER,
      path        TEXT    UNIQUE NOT NULL,
      "default"   BOOLEAN DEFAULT FALSE,
      creator     TEXT,
      attribution TEXT,
      sourcelink  TEXT,
      license     TEXT,
      licenselink TEXT,
      uploader    TEXT,
      lastchangedby TEXT,
      caption     TEXT DEFAULT '',
      sort_order  INTEGER DEFAULT 0 NOT NULL,
      FOREIGN KEY (species_id) REFERENCES species (id) ON DELETE CASCADE,
      FOREIGN KEY (source_id) REFERENCES source (id) ON DELETE CASCADE
    );
    INSERT INTO image_new SELECT * FROM image;
    DROP TABLE image;
    ALTER TABLE image_new RENAME TO image;
    CREATE INDEX "image_species_id_sort_order_index" ON "image" ("species_id", "sort_order");
    PRAGMA foreign_keys = ON;
    """)
  end
end
