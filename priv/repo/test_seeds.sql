-- Test seed data for gallformers test database
-- This file is loaded after structure.sql to provide minimal data for tests
--
-- Keep this minimal - only add data that tests actually need

-- =============================================================================
-- Reference Data (required by foreign keys)
-- =============================================================================

-- Taxon types (referenced by species and gall)
INSERT INTO taxontype (taxoncode, description) VALUES
  ('gall', 'Gall-forming species'),
  ('plant', 'Host plant species');

-- Abundances (referenced by species)
INSERT INTO abundance (id, abundance) VALUES
  (1, 'common'),
  (2, 'uncommon'),
  (3, 'rare');

-- =============================================================================
-- Species (for search/FTS tests)
-- =============================================================================

-- Host plants (taxoncode = 'plant')
INSERT INTO species (id, name, taxoncode, datacomplete, abundance_id) VALUES
  (1, 'Quercus alba', 'plant', 0, 1),
  (2, 'Quercus rubra', 'plant', 0, 1),
  (3, 'Quercus velutina', 'plant', 0, 2),
  (4, 'Acer rubrum', 'plant', 0, 1),
  (5, 'Acer saccharum', 'plant', 0, 2);

-- Gall-forming species (taxoncode = 'gall')
INSERT INTO species (id, name, taxoncode, datacomplete, abundance_id) VALUES
  (100, 'Andricus quercuscalifornicus', 'gall', 0, 1),
  (101, 'Amphibolips confluenta', 'gall', 0, 2),
  (102, 'Callirhytis quercuspunctata', 'gall', 0, 3);

-- Gall records (linked to gall species)
INSERT INTO gall (id, taxoncode, detachable, undescribed) VALUES
  (1, 'gall', 1, 0),
  (2, 'gall', 0, 0),
  (3, 'gall', 1, 1);

-- Link gall species to gall records
INSERT INTO gallspecies (gall_id, species_id) VALUES
  (1, 100),
  (2, 101),
  (3, 102);

-- =============================================================================
-- Aliases (for search tests)
-- =============================================================================

-- Note: type must be 'common' or 'scientific' per CHECK constraint
INSERT INTO alias (id, name, type, description) VALUES
  (1, 'White Oak', 'common', ''),
  (2, 'Red Oak', 'common', ''),
  (3, 'Oak Apple Gall Wasp', 'common', '');

INSERT INTO aliasspecies (alias_id, species_id) VALUES
  (1, 1),
  (2, 2),
  (3, 100);

-- =============================================================================
-- FTS Index (for full-text search tests)
-- =============================================================================

INSERT INTO species_fts (species_id, name, aliases) VALUES
  (1, 'Quercus alba', 'White Oak'),
  (2, 'Quercus rubra', 'Red Oak'),
  (3, 'Quercus velutina', ''),
  (4, 'Acer rubrum', ''),
  (5, 'Acer saccharum', ''),
  (100, 'Andricus quercuscalifornicus', 'Oak Apple Gall Wasp'),
  (101, 'Amphibolips confluenta', ''),
  (102, 'Callirhytis quercuspunctata', '');

-- =============================================================================
-- Articles
-- =============================================================================
-- Note: Article tests use Ecto sandbox and create their own test data.
-- Do NOT seed articles here - it will break tests that expect an empty state.
