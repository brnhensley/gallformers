CREATE TABLE IF NOT EXISTS "migration" (
  id   INTEGER PRIMARY KEY,
  name TEXT    NOT NULL,
  up   TEXT    NOT NULL,
  down TEXT    NOT NULL
);
CREATE TABLE location (
    id INTEGER PRIMARY KEY NOT NULL,
    location TEXT UNIQUE NOT NULL,
    description TEXT
);
CREATE TABLE texture (
    id INTEGER PRIMARY KEY NOT NULL,
    texture TEXT UNIQUE NOT NULL,
    description TEXT
);
CREATE TABLE walls (
    id INTEGER PRIMARY KEY NOT NULL,
    walls TEXT UNIQUE NOT NULL,
    description TEXT
);
CREATE TABLE cells (
    id INTEGER PRIMARY KEY NOT NULL,
    cells TEXT UNIQUE NOT NULL,
    description TEXT
);
CREATE TABLE color (
    id INTEGER PRIMARY KEY NOT NULL,
    color TEXT UNIQUE NOT NULL
);
CREATE TABLE alignment (
    id INTEGER PRIMARY KEY NOT NULL,
    alignment TEXT UNIQUE NOT NULL,
    description TEXT
);
CREATE TABLE shape (
    id INTEGER PRIMARY KEY NOT NULL,
    shape TEXT UNIQUE NOT NULL,
    description TEXT
);
CREATE TABLE abundance (
    id INTEGER PRIMARY KEY NOT NULL,
    abundance TEXT UNIQUE NOT NULL,
    description TEXT,
    reference TEXT
);
CREATE TABLE taxontype (
    taxoncode   TEXT PRIMARY KEY NOT NULL,
    description TEXT UNIQUE NOT NULL
);
CREATE TABLE glossary (
    id INTEGER PRIMARY KEY NOT NULL,
    word TEXT UNIQUE NOT NULL,
    definition TEXT NOT NULL,
    urls TEXT NOT NULL -- Tab separated list of URLs (tabs since commas can occur in URLs but tabs cannot)
);
CREATE TABLE source (
    id       INTEGER PRIMARY KEY
                     NOT NULL,
    title    TEXT    UNIQUE
                     NOT NULL,
    author   TEXT   NOT NULL, -- add NOT NULL in 004
    pubyear  TEXT NOT NULL, -- add NOT NULL in 004
    link     TEXT NOT NULL, -- add NOT NULL in 004
    citation TEXT NOT NULL -- add NOT NULL in 004
, datacomplete BOOLEAN DEFAULT 0 NOT NULL, license TEXT DEFAULT '' NOT NULL, licenselink TEXT DEFAULT '' NOT NULL);
CREATE TABLE host (
    id              INTEGER PRIMARY KEY
                            NOT NULL,
    host_species_id INTEGER,
    gall_species_id INTEGER,
    FOREIGN KEY (
        host_species_id
    )
    REFERENCES species (id) ON DELETE CASCADE,
    FOREIGN KEY (
        gall_species_id
    )
    REFERENCES species (id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS "image" (
    id          INTEGER PRIMARY KEY
                        NOT NULL,
    species_id  INTEGER NOT NULL,
    source_id   INTEGER,
    path        TEXT    UNIQUE
                        NOT NULL,
    [default]   BOOLEAN DEFAULT FALSE,
    creator     TEXT,
    attribution TEXT,
    sourcelink  TEXT,
    license     TEXT,
    licenselink TEXT,
    uploader    TEXT,
    lastchangedby TEXT, caption TEXT DEFAULT '',
    FOREIGN KEY (
        species_id
    )
    REFERENCES species (id) ON DELETE CASCADE,
    FOREIGN KEY (
        source_id
    )
    REFERENCES source (id) ON DELETE CASCADE
);
CREATE TABLE alias (
    id       INTEGER PRIMARY KEY NOT NULL,
    name     TEXT NOT NULL,
    type     TEXT NOT NULL CHECK (type = 'common' OR type = 'scientific'),
    description TEXT NOT NULL DEFAULT ''
);
CREATE TABLE speciestaxonomy (
    species_id   INTEGER NOT NULL,
    taxonomy_id  INTEGER NOT NULL,
    FOREIGN KEY (species_id) REFERENCES species (id) ON DELETE CASCADE,
    FOREIGN KEY (taxonomy_id) REFERENCES taxonomy (id) ON DELETE CASCADE,
    PRIMARY KEY(species_id, taxonomy_id)
);
CREATE TABLE taxonomytaxonomy (
    taxonomy_id  INTEGER NOT NULL,
    child_id  INTEGER NOT NULL,
    FOREIGN KEY (taxonomy_id) REFERENCES taxonomy (id) ON DELETE CASCADE,
    FOREIGN KEY (child_id) REFERENCES taxonomy (id) ON DELETE CASCADE,
    PRIMARY KEY(taxonomy_id, child_id)
);
CREATE TABLE IF NOT EXISTS "aliasspecies" (
    species_id  INTEGER NOT NULL,
    alias_id    INTEGER NOT NULL,
    FOREIGN KEY (species_id) REFERENCES species (id) ON DELETE CASCADE,
    FOREIGN KEY (alias_id) REFERENCES alias (id) ON DELETE CASCADE,
    PRIMARY KEY (species_id, alias_id)
);
CREATE TABLE IF NOT EXISTS "gallspecies" (
    species_id  INTEGER NOT NULL,
    gall_id    INTEGER NOT NULL,
    FOREIGN KEY (species_id) REFERENCES species (id) ON DELETE CASCADE,
    FOREIGN KEY (gall_id) REFERENCES gall (id) ON DELETE CASCADE,
    PRIMARY KEY (species_id, gall_id)
);
CREATE TABLE IF NOT EXISTS "taxonomyalias" (
    taxonomy_id  INTEGER NOT NULL,
    alias_id    INTEGER NOT NULL,
    FOREIGN KEY (taxonomy_id) REFERENCES taxonomy (id) ON DELETE CASCADE,
    FOREIGN KEY (alias_id) REFERENCES alias (id) ON DELETE CASCADE,
    PRIMARY KEY (taxonomy_id, alias_id)
);
CREATE TABLE IF NOT EXISTS "gall" (
    id          INTEGER PRIMARY KEY NOT NULL,
    taxoncode   TEXT    NOT NULL CHECK (taxoncode = 'gall'),
    detachable  INTEGER,
    undescribed BOOLEAN NOT NULL DEFAULT 0,
    FOREIGN KEY (taxoncode) REFERENCES taxontype (taxoncode) 
);
CREATE TABLE IF NOT EXISTS "species" (
    id           INTEGER PRIMARY KEY NOT NULL,
    taxoncode    TEXT,
    name         TEXT    UNIQUE NOT NULL,
    datacomplete BOOLEAN DEFAULT 0 NOT NULL,
    abundance_id INTEGER,
    FOREIGN KEY (
        taxoncode
    )
    REFERENCES taxontype (taxoncode),
    FOREIGN KEY (
        abundance_id
    )
    REFERENCES abundance (id) 
);
CREATE TABLE IF NOT EXISTS "gallcolor" (
    gall_id  INTEGER NOT NULL,
    color_id INTEGER NOT NULL,
    FOREIGN KEY (gall_id) REFERENCES gall (id) ON DELETE CASCADE,
    FOREIGN KEY (color_id) REFERENCES color (id) ON DELETE CASCADE,
    PRIMARY KEY (gall_id, color_id)
);
CREATE TABLE IF NOT EXISTS "gallshape" (
    gall_id  INTEGER NOT NULL,
    shape_id INTEGER NOT NULL,
    FOREIGN KEY (gall_id) REFERENCES gall (id) ON DELETE CASCADE,
    FOREIGN KEY (shape_id) REFERENCES shape (id) ON DELETE CASCADE,
    PRIMARY KEY (gall_id, shape_id)
);
CREATE TABLE IF NOT EXISTS "gallcells" (
    gall_id  INTEGER NOT NULL,
    cells_id INTEGER NOT NULL,
    FOREIGN KEY (gall_id) REFERENCES gall (id) ON DELETE CASCADE,
    FOREIGN KEY (cells_id) REFERENCES cells (id) ON DELETE CASCADE,
    PRIMARY KEY (gall_id, cells_id)
);
CREATE TABLE IF NOT EXISTS "gallwalls" (
    gall_id  INTEGER NOT NULL,
    walls_id INTEGER NOT NULL,
    FOREIGN KEY (gall_id) REFERENCES gall (id) ON DELETE CASCADE,
    FOREIGN KEY (walls_id) REFERENCES walls (id) ON DELETE CASCADE,
    PRIMARY KEY (gall_id, walls_id)
);
CREATE TABLE IF NOT EXISTS "gallalignment" (
    gall_id  INTEGER NOT NULL,
    alignment_id INTEGER NOT NULL,
    FOREIGN KEY (gall_id) REFERENCES gall (id) ON DELETE CASCADE,
    FOREIGN KEY (alignment_id) REFERENCES alignment (id) ON DELETE CASCADE,
    PRIMARY KEY (gall_id, alignment_id)    
);
CREATE TABLE IF NOT EXISTS "speciessource" (
    id           INTEGER PRIMARY KEY NOT NULL,
    species_id   INTEGER NOT NULL,
    source_id    INTEGER NOT NULL,
    description  TEXT    DEFAULT '' NOT NULL,
    useasdefault INTEGER DEFAULT 0 NOT NULL,
    externallink TEXT    DEFAULT '' NOT NULL,
    alias_id     INTEGER,
    FOREIGN KEY (species_id) REFERENCES species (id) ON DELETE CASCADE,
    FOREIGN KEY (source_id) REFERENCES source (id) ON DELETE CASCADE,
    FOREIGN KEY (alias_id) REFERENCES alias (id)
);
CREATE TABLE season (
    id INTEGER PRIMARY KEY NOT NULL,
    season TEXT UNIQUE NOT NULL
);
CREATE TABLE gallseason (
    id       INTEGER PRIMARY KEY NOT NULL,
    gall_id  INTEGER,
    season_id INTEGER,
    FOREIGN KEY (gall_id) REFERENCES gall (id) ON DELETE CASCADE,
    FOREIGN KEY (season_id) REFERENCES season (id) ON DELETE CASCADE 
);
CREATE TABLE IF NOT EXISTS "taxonomy" (
    id          INTEGER PRIMARY KEY
                        NOT NULL,
    name        TEXT    NOT NULL,
    description TEXT    DEFAULT '',
    type        TEXT    NOT NULL
                        CHECK (type = 'family' OR 
                               type = 'genus' OR 
                               type = 'section'),
    parent_id   INTEGER DEFAULT NULL,
    FOREIGN KEY (
        parent_id
    )
    REFERENCES taxonomy (id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS "galltexture" (
    gall_id    INTEGER NOT NULL,
    texture_id INTEGER NOT NULL,
    FOREIGN KEY (gall_id) REFERENCES gall (id) ON DELETE CASCADE,
    FOREIGN KEY (texture_id) REFERENCES texture (id) ON DELETE CASCADE,
    PRIMARY KEY (gall_id, texture_id)
);
CREATE TABLE IF NOT EXISTS "galllocation" (
    gall_id     INTEGER NOT NULL,
    location_id INTEGER NOT NULL,
    FOREIGN KEY (gall_id) REFERENCES gall (id) ON DELETE CASCADE,
    FOREIGN KEY (location_id) REFERENCES location (id) ON DELETE CASCADE,
    PRIMARY KEY (gall_id, location_id)
);
CREATE TABLE form (
    id          INTEGER PRIMARY KEY NOT NULL,
    form        TEXT    UNIQUE NOT NULL,
    description TEXT
);
CREATE TABLE gallform (
    gall_id  INTEGER NOT NULL,
    form_id INTEGER NOT NULL,
    FOREIGN KEY (gall_id) REFERENCES gall (id) ON DELETE CASCADE,
    FOREIGN KEY (form_id) REFERENCES form (id) ON DELETE CASCADE,
    PRIMARY KEY (gall_id, form_id)
);
CREATE TABLE place (
    id INTEGER PRIMARY KEY NOT NULL,
    name TEXT UNIQUE NOT NULL,
    code TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ("continent", "country", "region", "state", "province", "county", "city") )
);
CREATE TABLE placeplace (
    place_id INTEGER,
    parent_id INTEGER,
    FOREIGN KEY (place_id) REFERENCES place (id) ON DELETE CASCADE,
    FOREIGN KEY (parent_id) REFERENCES place (id) ON DELETE CASCADE,
    PRIMARY KEY (place_id, parent_id)

);
CREATE TABLE speciesplace (
    species_id INTEGER,
    place_id INTEGER,
    FOREIGN KEY (species_id) REFERENCES species (id) ON DELETE CASCADE,
    FOREIGN KEY (place_id) REFERENCES place (id) ON DELETE CASCADE,
    PRIMARY KEY (species_id, place_id)
);
