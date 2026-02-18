---
status: raw
effort: 5 days
created: 2026-02-13
updated: 2026-02-18
epic: admin
relates: [ec68, 5c56]
needs: [ec68]
---

# Audit trail

Full tracing of data changes: who changed what, when, including deletes. Safety net for growing admin base. Design exists: docs/plans/completed/2026-01-31-audit-trail-and-cascade-protection-design.md (Phase 1 CASCADE done, Phase 3 audit trail not started). Consider ex_audit integration.

## Background

Phase 1 (CASCADE fixes + informed delete) is complete — RESTRICT constraints applied, cascade delete confirmation modal designed. This matter covers Phase 2: the audit trail itself.

Design source: docs/plans/completed/2026-01-31-audit-trail-and-cascade-protection-design.md

## Chosen Approach: ex_audit

Evaluated Dolt, PaperTrail, ex_audit, SQLite triggers, soft delete, manual Ecto.Multi. ex_audit won — transparent Repo wrapping, EETF storage in binary columns, extensible schema. Limitation: cannot track DB-level CASCADE deletes (mitigated by RESTRICT constraints preventing cascades).

## Implementation

### Database: versions table

```sql
CREATE TABLE versions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  entity_schema TEXT NOT NULL,
  entity_id INTEGER NOT NULL,
  action TEXT NOT NULL,          -- created, updated, deleted
  patch BLOB NOT NULL,           -- EETF serialized record state
  recorded_at DATETIME NOT NULL,
  rollback BOOLEAN DEFAULT 0,
  user_id TEXT,                  -- Auth0 user ID
  user_name TEXT,                -- Display name at time of change
  deletion_reason TEXT           -- Required for sensitive deletes
);
```

### Repo enhancement

Add `use ExAudit.Repo` to `Gallformers.Repo`. Configure tracked schemas in config.

### User context tracking

Plug captures current user and passes to ExAudit via `ExAudit.track(conn, %{user_id: ..., user_name: ...})`.

### Deletion reason collection

Enhanced delete confirmation modal collects reason text for audit trail.

### Restore capability

```elixir
def restore_from_version(version_id) do
  version = Repo.get!(Version, version_id)
  original_record = ExAudit.Tracking.deserialize_patch(version.patch)
  Repo.insert(original_record)
end
```

No cascade restore needed because RESTRICT prevents cascade deletes.

## Open Questions

1. **Restore UI**: Admin UI for browsing/restoring versions, or iex-only?
2. **Retention**: How long to keep audit records?
3. **Performance**: Will audit logging impact high-volume operations?
4. **Scope**: Track all schemas or start with a subset (species, taxonomy, images)?

## Note on Postgres migration

If 4474 (Postgres migration) happens first, ex_audit's EETF storage becomes less relevant — could use JSONB instead for queryable audit records. Worth sequencing this after the Postgres decision.
