-- Cleanup Orphaned Records Script
-- Purpose: Remove orphaned records before V1→V2 migration
-- Date: 2026-02-04
--
-- Expected cleanup counts (as of 2026-01-23):
-- - 218 orphaned gall records (5.6% of total)
-- - 8,820 orphaned alias records (72.1% of total)
-- - 1,162 orphaned filter associations
--
-- Run this against gallformers-v1-clean.sqlite before migration
-- Usage: sqlite3 gallformers-v1-clean.sqlite < cleanup_orphaned_records.sql

BEGIN TRANSACTION;

-- Delete orphaned gall records
-- These are galls that have no speciestaxon relationship
DELETE FROM gall
WHERE id NOT IN (
  SELECT DISTINCT gall_id
  FROM speciestaxon
  WHERE gall_id IS NOT NULL
);

-- Delete orphaned alias records
-- These are aliases that have no species or host relationship
DELETE FROM alias
WHERE id NOT IN (
  SELECT DISTINCT alias_id FROM speciesalias WHERE alias_id IS NOT NULL
  UNION
  SELECT DISTINCT alias_id FROM hostalias WHERE alias_id IS NOT NULL
);

-- Delete orphaned gall filter associations
-- These reference galls that no longer exist

DELETE FROM gallcolor
WHERE gall_id NOT IN (SELECT id FROM gall);

DELETE FROM gallshape
WHERE gall_id NOT IN (SELECT id FROM gall);

DELETE FROM galltexture
WHERE gall_id NOT IN (SELECT id FROM gall);

DELETE FROM gallalignment
WHERE gall_id NOT IN (SELECT id FROM gall);

DELETE FROM gallwalls
WHERE gall_id NOT IN (SELECT id FROM gall);

DELETE FROM gallcells
WHERE gall_id NOT IN (SELECT id FROM gall);

DELETE FROM galllocation
WHERE gall_id NOT IN (SELECT id FROM gall);

DELETE FROM gallform
WHERE gall_id NOT IN (SELECT id FROM gall);

DELETE FROM gallseason
WHERE gall_id NOT IN (SELECT id FROM gall);

COMMIT;

-- Verification queries
-- Run these to confirm cleanup was successful
SELECT 'Orphaned galls remaining:' as check_type, COUNT(*) as count
FROM gall
WHERE id NOT IN (
  SELECT DISTINCT gall_id FROM speciestaxon WHERE gall_id IS NOT NULL
);

SELECT 'Orphaned aliases remaining:' as check_type, COUNT(*) as count
FROM alias
WHERE id NOT IN (
  SELECT DISTINCT alias_id FROM speciesalias
  UNION
  SELECT DISTINCT alias_id FROM hostalias
);

SELECT 'Orphaned gallcolor remaining:' as check_type, COUNT(*) as count
FROM gallcolor WHERE gall_id NOT IN (SELECT id FROM gall);

SELECT 'Orphaned gallshape remaining:' as check_type, COUNT(*) as count
FROM gallshape WHERE gall_id NOT IN (SELECT id FROM gall);

SELECT 'Orphaned galltexture remaining:' as check_type, COUNT(*) as count
FROM galltexture WHERE gall_id NOT IN (SELECT id FROM gall);

SELECT 'Orphaned gallalignment remaining:' as check_type, COUNT(*) as count
FROM gallalignment WHERE gall_id NOT IN (SELECT id FROM gall);

SELECT 'Orphaned gallwalls remaining:' as check_type, COUNT(*) as count
FROM gallwalls WHERE gall_id NOT IN (SELECT id FROM gall);

SELECT 'Orphaned gallcells remaining:' as check_type, COUNT(*) as count
FROM gallcells WHERE gall_id NOT IN (SELECT id FROM gall);

SELECT 'Orphaned galllocation remaining:' as check_type, COUNT(*) as count
FROM galllocation WHERE gall_id NOT IN (SELECT id FROM gall);

SELECT 'Orphaned gallform remaining:' as check_type, COUNT(*) as count
FROM gallform WHERE gall_id NOT IN (SELECT id FROM gall);

SELECT 'Orphaned gallseason remaining:' as check_type, COUNT(*) as count
FROM gallseason WHERE gall_id NOT IN (SELECT id FROM gall);
