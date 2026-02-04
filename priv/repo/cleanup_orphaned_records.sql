-- Cleanup Orphaned Records Script
-- Purpose: Remove orphaned records before V1→V2 migration
-- Date: 2026-02-04
--
-- Run this against a V1 database before migration
-- Usage: sqlite3 gallformers.sqlite < cleanup_orphaned_records.sql

-- Report counts before cleanup
SELECT '=== Records to be deleted ===' as status;

-- True orphans: gall records not linked to any gall-type species via gallspecies
SELECT 'Orphaned galls (no valid gallspecies link):' as record_type, COUNT(*) as count
FROM gall g
WHERE g.id NOT IN (
  SELECT gs.gall_id
  FROM gallspecies gs
  JOIN species s ON gs.species_id = s.id
  WHERE s.taxoncode = 'gall'
);

SELECT 'Orphaned aliases:' as record_type, COUNT(*) as count
FROM alias WHERE id NOT IN (SELECT DISTINCT alias_id FROM aliasspecies UNION SELECT DISTINCT alias_id FROM taxonomyalias);

SELECT 'Orphaned gallcolor:' as record_type, COUNT(*) as count FROM gallcolor WHERE gall_id NOT IN (SELECT id FROM gall);
SELECT 'Orphaned gallshape:' as record_type, COUNT(*) as count FROM gallshape WHERE gall_id NOT IN (SELECT id FROM gall);
SELECT 'Orphaned galltexture:' as record_type, COUNT(*) as count FROM galltexture WHERE gall_id NOT IN (SELECT id FROM gall);
SELECT 'Orphaned gallalignment:' as record_type, COUNT(*) as count FROM gallalignment WHERE gall_id NOT IN (SELECT id FROM gall);
SELECT 'Orphaned gallwalls:' as record_type, COUNT(*) as count FROM gallwalls WHERE gall_id NOT IN (SELECT id FROM gall);
SELECT 'Orphaned gallcells:' as record_type, COUNT(*) as count FROM gallcells WHERE gall_id NOT IN (SELECT id FROM gall);
SELECT 'Orphaned galllocation:' as record_type, COUNT(*) as count FROM galllocation WHERE gall_id NOT IN (SELECT id FROM gall);
SELECT 'Orphaned gallform:' as record_type, COUNT(*) as count FROM gallform WHERE gall_id NOT IN (SELECT id FROM gall);
SELECT 'Orphaned gallseason:' as record_type, COUNT(*) as count FROM gallseason WHERE gall_id NOT IN (SELECT id FROM gall);

SELECT '=== Performing cleanup ===' as status;

BEGIN TRANSACTION;

-- Delete orphaned gall records (not linked to any gall-type species via gallspecies)
DELETE FROM gall
WHERE id NOT IN (
  SELECT gs.gall_id
  FROM gallspecies gs
  JOIN species s ON gs.species_id = s.id
  WHERE s.taxoncode = 'gall'
);
SELECT 'Deleted orphaned galls:' as action, changes() as count;

-- Delete orphaned alias records (aliases not linked to species or taxonomy)
DELETE FROM alias
WHERE id NOT IN (SELECT DISTINCT alias_id FROM aliasspecies UNION SELECT DISTINCT alias_id FROM taxonomyalias);
SELECT 'Deleted aliases:' as action, changes() as count;

-- Delete orphaned gall filter associations (reference galls that no longer exist)
DELETE FROM gallcolor WHERE gall_id NOT IN (SELECT id FROM gall);
SELECT 'Deleted gallcolor:' as action, changes() as count;

DELETE FROM gallshape WHERE gall_id NOT IN (SELECT id FROM gall);
SELECT 'Deleted gallshape:' as action, changes() as count;

DELETE FROM galltexture WHERE gall_id NOT IN (SELECT id FROM gall);
SELECT 'Deleted galltexture:' as action, changes() as count;

DELETE FROM gallalignment WHERE gall_id NOT IN (SELECT id FROM gall);
SELECT 'Deleted gallalignment:' as action, changes() as count;

DELETE FROM gallwalls WHERE gall_id NOT IN (SELECT id FROM gall);
SELECT 'Deleted gallwalls:' as action, changes() as count;

DELETE FROM gallcells WHERE gall_id NOT IN (SELECT id FROM gall);
SELECT 'Deleted gallcells:' as action, changes() as count;

DELETE FROM galllocation WHERE gall_id NOT IN (SELECT id FROM gall);
SELECT 'Deleted galllocation:' as action, changes() as count;

DELETE FROM gallform WHERE gall_id NOT IN (SELECT id FROM gall);
SELECT 'Deleted gallform:' as action, changes() as count;

DELETE FROM gallseason WHERE gall_id NOT IN (SELECT id FROM gall);
SELECT 'Deleted gallseason:' as action, changes() as count;

COMMIT;

SELECT '=== Cleanup complete ===' as status;
