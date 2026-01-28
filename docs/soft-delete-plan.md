# Soft Delete Implementation Plan

**Date:** 2026-01-27
**Status:** Planning Complete
**Tracking:** gallformers-5e9m (parent), gallformers-3jpe (trigger tool), gallformers-nd8r (tracer bullet)

## Problem Statement

Gallformers currently hard-deletes records. This creates risk:
- Accidental deletions are unrecoverable
- Taxonomy cascades can delete wide swaths of data
- No audit trail of what was deleted, when, or by whom
- Orphaned records already exist (218 galls, 8820 aliases, 1162 filter associations)

## Decision: Trigger-Based Audit Log

After researching Elixir/Ecto patterns, we rejected traditional soft delete (`deleted_at` column) because:
- Pollutes every query with `WHERE deleted_at IS NULL`
- Foreign key cascades don't respect soft delete flags
- Soft deletion logic bleeds into all parts of the codebase
- Views-based workarounds have significant limitations (GROUP BY failures, schema evolution pain)

**Chosen approach:** SQLite triggers that copy deleted records to a JSON audit log table, then allow the hard delete to proceed. This keeps main tables and queries clean.

### Key Sources

- [Dashbit: Soft deletes with Ecto](https://dashbit.co/blog/soft-deletes-with-ecto) - why views are complex
- [Dan Schultzer: Deleted record audit log](https://danschultzer.com/posts/deleted-record-audit-log-with-ecto-postgresql) - PostgreSQL trigger approach
- [Simon Willison: SQLite JSON audit log](https://til.simonwillison.net/sqlite/json-audit-log) - SQLite-specific implementation
- [Flagrant: A Soft Deletion Story](https://www.beflagrant.com/blog/a-soft-deletion-story-2024-02-06) - lessons learned from views approach

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Elixir App Layer                     │
│  ┌─────────────────────────────────────────────────┐   │
│  │  delete_with_audit(record, user_id, reason)     │   │
│  │    1. Generate batch_id (UUID)                  │   │
│  │    2. Insert context → _deletion_context table  │   │
│  │    3. Repo.delete(record) → triggers fire       │   │
│  │    4. Clean up context                          │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                    SQLite Triggers                      │
│  AFTER DELETE ON sources → read context, log to audit   │
│  AFTER DELETE ON galls   → read context, log to audit   │
│  AFTER DELETE ON hosts   → read context, log to audit   │
│       (cascade deletes fire their own triggers)         │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│               deleted_record_log table                  │
│  - id (primary key)                                     │
│  - table_name (which table the record came from)        │
│  - row_id (original primary key)                        │
│  - data (full record as JSON)                           │
│  - deleted_at (timestamp)                               │
│  - deleted_by (user ID from Auth0)                      │
│  - delete_reason (optional explanation)                 │
│  - batch_id (groups cascade deletes together)           │
└─────────────────────────────────────────────────────────┘
```

## Cascade Handling

When deleting a taxonomy record that cascades to many children:

1. App layer generates `batch_id` (UUID), writes to `_deletion_context`
2. Parent table's trigger fires, logs with that `batch_id`
3. SQLite CASCADE triggers fire for each child table
4. Each child trigger reads the same `batch_id` from context
5. Result: All related deletions grouped under one `batch_id` for easy identification

## SQLite Considerations

SQLite lacks some PostgreSQL features, requiring adaptations:

| Feature | PostgreSQL | SQLite | Our Approach |
|---------|------------|--------|--------------|
| `row_to_json(OLD)` | ✅ | ❌ | Enumerate columns in `json_object()` |
| Session parameters | ✅ `SET LOCAL` | ❌ | Use `_deletion_context` table |
| JSONB type | ✅ | ❌ | TEXT column with JSON functions |
| Partial indexes | ✅ | ❌ | Not needed for audit table |

## Implementation Phases

### Phase 1: Trigger Generator Tool (gallformers-3jpe)

Build a TDD tool that generates SQLite triggers from Ecto schemas:

**Input:** Ecto schema module (e.g., `Gallformers.Sources.Source`)

**Output:** SQL like:
```sql
CREATE TRIGGER audit_sources_delete AFTER DELETE ON sources
BEGIN
  INSERT INTO deleted_record_log (table_name, row_id, data, deleted_at, deleted_by, delete_reason, batch_id)
  SELECT
    'sources',
    OLD.id,
    json_object(
      'id', OLD.id,
      'title', OLD.title,
      'author', OLD.author,
      'pubyear', OLD.pubyear,
      -- ... all fields
    ),
    datetime('now'),
    (SELECT value FROM _deletion_context WHERE key = 'deleted_by'),
    (SELECT value FROM _deletion_context WHERE key = 'delete_reason'),
    (SELECT value FROM _deletion_context WHERE key = 'batch_id');
END;
```

**TDD approach:**
1. Test field enumeration from schema
2. Test JSON object generation for various types
3. Test complete trigger SQL generation
4. Test integration with actual SQLite

### Phase 2: Tracer Bullet with Sources (gallformers-nd8r)

Implement the full pattern for one table to validate the architecture:

1. **Migration:** Create `deleted_record_log` and `_deletion_context` tables
2. **Trigger:** Generate and apply trigger for `sources` table
3. **Elixir wrapper:** `delete_with_audit/3` function
4. **Integration:** Wire into existing source deletion flow
5. **Testing:** Verify cascade behavior with `source_species` associations

### Phase 3: Roll Out to Other Tables

After tracer bullet validates the pattern:
- Galls (complex, many associations)
- Hosts
- Species
- Taxonomy (most critical for cascade protection)

### Phase 4: Image Handling (Separate)

S3 images need special treatment:
- Log image keys in audit record
- Decide: delete immediately, delay, or keep permanently?
- Potentially move to "deleted" S3 prefix instead of deleting

### Phase 5: Restore Functionality (Future)

Build admin UI to browse and restore deleted records:
- View audit log entries
- Filter by table, user, date, batch_id
- Restore individual records or entire batches
- Handle foreign key reconstruction

## Database Schema

### deleted_record_log

```sql
CREATE TABLE deleted_record_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  table_name TEXT NOT NULL,
  row_id INTEGER NOT NULL,
  data TEXT NOT NULL,  -- JSON blob
  deleted_at TEXT NOT NULL DEFAULT (datetime('now')),
  deleted_by TEXT,     -- Auth0 user ID
  delete_reason TEXT,
  batch_id TEXT        -- UUID grouping cascade deletes
);

CREATE INDEX idx_deleted_record_log_table ON deleted_record_log(table_name);
CREATE INDEX idx_deleted_record_log_batch ON deleted_record_log(batch_id);
CREATE INDEX idx_deleted_record_log_deleted_at ON deleted_record_log(deleted_at);
```

### _deletion_context

```sql
CREATE TABLE _deletion_context (
  key TEXT PRIMARY KEY,
  value TEXT
);
```

## Elixir API

```elixir
defmodule Gallformers.Repo.AuditDelete do
  @doc """
  Deletes a record with full audit logging.

  Sets deletion context (user, reason, batch_id) before delete,
  allowing SQLite triggers to capture the metadata.
  """
  def delete_with_audit(record, user_id, reason \\ nil) do
    batch_id = Ecto.UUID.generate()

    Repo.transaction(fn ->
      # Set context for triggers to read
      set_deletion_context(user_id, reason, batch_id)

      # Perform delete (triggers fire here)
      case Repo.delete(record) do
        {:ok, deleted} ->
          clear_deletion_context()
          deleted
        {:error, changeset} ->
          clear_deletion_context()
          Repo.rollback(changeset)
      end
    end)
  end

  defp set_deletion_context(user_id, reason, batch_id) do
    Repo.query!("INSERT OR REPLACE INTO _deletion_context VALUES ('deleted_by', ?)", [user_id])
    Repo.query!("INSERT OR REPLACE INTO _deletion_context VALUES ('delete_reason', ?)", [reason])
    Repo.query!("INSERT OR REPLACE INTO _deletion_context VALUES ('batch_id', ?)", [batch_id])
  end

  defp clear_deletion_context do
    Repo.query!("DELETE FROM _deletion_context")
  end
end
```

## Benefits

1. **Clean queries:** No `deleted_at IS NULL` filtering anywhere
2. **Guaranteed capture:** Triggers catch even manual SQL deletes
3. **Cascade tracking:** `batch_id` groups related deletions
4. **Audit trail:** Know who deleted what, when, and why
5. **Recoverable:** JSON blobs enable future restore functionality
6. **Minimal invasion:** Existing code mostly unchanged

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Trigger generation bugs | TDD approach, test against real SQLite |
| Context table race conditions | Single-user admin operations; could add connection ID if needed |
| Audit table grows large | Add retention policy, archive old records to S3 |
| Restore is complex | Defer to Phase 5; JSON format enables future flexibility |

## Open Questions (Deferred)

1. **Retention policy:** How long to keep audit records before archiving to S3?
2. **Image handling:** Delete S3 objects immediately or delay?
3. **Restore UX:** Admin interface design for browsing/restoring
4. **Concurrency:** If multiple admins delete simultaneously, do we need connection-scoped context?

## Next Steps

1. [ ] Implement trigger generator tool (gallformers-3jpe)
2. [ ] Implement Sources tracer bullet (gallformers-nd8r)
3. [ ] Validate pattern works for cascading deletes
4. [ ] Roll out to remaining tables
5. [ ] Close gallformers-5e9m when complete
