# Audit Trail and Cascade Delete Protection - Design Document

**Date:** 2026-01-31
**Status:** Design Complete - Ready for Implementation Planning
**Author:** Claude + Jeff

---

## Problem Statement

### Historical Context

The Gallformers team has experienced **significant data loss trauma** from cascade delete operations:

- Deletion of a Genus cascaded to all associated Species and their related data
- Manual recovery required from old backups with carefully constructed restore processes
- Team members still anxious about data deletion operations
- Current mitigation: warnings in UI + restricted delete access to superadmins only

### Current State

**Database Analysis:**
- 43 total foreign key constraints
- **39 have `ON DELETE CASCADE`** (91%)
- 4 have `RESTRICT` or `NO ACTION`

**Critical cascade paths identified:**
1. `taxonomy` (Genus) → `speciestaxonomy` → orphaned Species
2. `species` → `images`, `host`, `gallspecies`, `speciessource`
3. `taxonomy.parent_id` (Family) → all child Genera
4. `gall` → 9+ characteristic join tables

### Requirements

✅ **Must prevent data loss from cascade deletes**
✅ **Must track who deleted what for accountability**
✅ **Must be able to restore deleted data**
✅ **Team must feel confident the system protects them**
✅ **Must handle race conditions safely**
✅ **Must require explanations for sensitive deletions**

---

## Research Summary

### Evaluated Approaches

| Approach | Pros | Cons | Verdict |
|----------|------|------|---------|
| **Dolt** (Git for data) | Native versioning, time-travel queries | Complete DB migration, infrastructure overhaul | ❌ Too invasive |
| **PaperTrail** | Mature, JSON snapshots | No explicit SQLite confirmation | ⚠️ Uncertain compatibility |
| **ex_audit** | Transparent, EETF storage, extensible | Doesn't track DB-level cascades | ✅ **Chosen** (with modifications) |
| **SQLite Triggers** | Captures all deletes including cascades | Less Elixir-idiomatic, harder to test | ⚠️ Backup option |
| **Soft Delete** | Never lose data | Messy queries, deleted data in main tables | ❌ Rejected by team |
| **Manual Ecto.Multi** | Full control, guaranteed compatible | High effort, defeats transparency | ❌ Too much work |

### Key Findings

**ex_audit:**
- Uses EETF (Erlang External Term Format) stored in `:binary` columns
- Works with SQLite (binary/BLOB support is native)
- Transparent wrapping of `Repo.insert/update/delete`
- **Limitation:** Cannot track database-level CASCADE deletes
- Extensible schema allows custom fields (user_id, deletion_reason, etc.)

**SQLite:**
- Can insert with explicit IDs (preserves original IDs on restore)
- `ON DELETE RESTRICT` prevents deletes if children exist
- RESTRICT solves BOTH cascade prevention AND race conditions
- Foreign key constraint changes require table rebuilds

---

## Chosen Architecture

### Core Strategy: Three-Part Solution

1. **ex_audit** - Transparent audit tracking
2. **ON DELETE RESTRICT** - Database-level cascade prevention
3. **Application validation** - User-friendly error handling + mandatory deletion reasons

### Why This Works

**Prevents cascades:**
- Database blocks CASCADE deletes with RESTRICT constraint
- Application validation provides friendly error messages
- UI forces users to handle dependencies explicitly

**Prevents race conditions:**
```
Thread 1: Check if Genus has children (0 found)
Thread 2: Add Species to Genus
Thread 1: Delete Genus → DATABASE BLOCKS (children exist now)
```

**Full audit trail:**
- Every delete tracked through ex_audit
- User context (who, when, why) captured
- Original record state preserved for restore
- No cascade tracking needed (cascades are prevented!)

---

## Design Details

### Database Schema

**New `versions` table:**

```sql
CREATE TABLE versions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,

  -- Core ex_audit fields
  entity_schema TEXT NOT NULL,      -- e.g., "species", "taxonomy"
  entity_id INTEGER NOT NULL,       -- ID of deleted/modified record
  action TEXT NOT NULL,             -- "created", "updated", "deleted"
  patch BLOB NOT NULL,              -- EETF serialized record state
  recorded_at DATETIME NOT NULL,
  rollback BOOLEAN DEFAULT 0,

  -- User tracking
  user_id TEXT,                     -- Auth0 user ID
  user_name TEXT,                   -- Display name at time of change

  -- Deletion accountability
  deletion_reason TEXT              -- Required for sensitive deletes
);

CREATE INDEX idx_versions_entity ON versions(entity_schema, entity_id);
CREATE INDEX idx_versions_user ON versions(user_id);
CREATE INDEX idx_versions_recorded_at ON versions(recorded_at);
CREATE INDEX idx_versions_action ON versions(action);
```

### Foreign Key Changes

**Phase 1: Critical Protection (7 constraints)**

```
CHANGE TO RESTRICT:
1. speciestaxonomy.species_id → species
2. speciestaxonomy.taxonomy_id → taxonomy
3. taxonomy.parent_id → taxonomy
4. image.species_id → species
5. gallspecies.species_id → species
6. host.gall_species_id → species
7. host.host_species_id → species
```

**Impact:** Protects the "delete Genus → lose everything" scenario.

**Phase 2: Gall Characteristics (9 constraints)**

```
CHANGE TO RESTRICT:
8-16. gall* join tables (gallalignment, gallcells, gallcolor, etc.)
```

**Impact:** Requires UI for "can't delete Gall, has characteristics."

**Phase 3: Review Remaining**

```
EVALUATE:
17-39. Other cascades (aliasspecies, placeplace, etc.)
```

**Decision criteria:** Is cascade intentional or dangerous?

---

## Application Code Changes

### 1. ex_audit Setup

**Dependencies:**
```elixir
# mix.exs
{:ex_audit, "~> 0.10"}
```

**Repo enhancement:**
```elixir
# lib/gallformers/repo.ex
defmodule Gallformers.Repo do
  use Ecto.Repo,
    otp_app: :gallformers,
    adapter: Ecto.Adapters.SQLite3

  use ExAudit.Repo  # Add this
end
```

**Configuration:**
```elixir
# config/config.exs
config :ex_audit,
  ecto_repos: [Gallformers.Repo],
  version_schema: Gallformers.Audit.Version,
  tracked_schemas: [
    Gallformers.Species.Species,
    Gallformers.Hosts.Host,
    Gallformers.Species.Gall,
    Gallformers.Taxonomy.Taxonomy,
    # ... all other schemas
  ]
```

### 2. User Context Tracking

**Plug to capture current user:**
```elixir
# lib/gallformers_web/plugs/audit_context.ex
defmodule GallformersWeb.Plugs.AuditContext do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case Gallformers.Accounts.get_user_from_session(conn) do
      %{id: user_id, name: name} ->
        ExAudit.track(conn, %{
          user_id: user_id,
          user_name: name
        })
      nil ->
        conn
    end
  end
end
```

**Add to router:**
```elixir
# lib/gallformers_web/router.ex
pipeline :browser do
  # ... existing plugs
  plug GallformersWeb.Plugs.AuditContext
end
```

### 3. Dependency Validation

**Context pattern:**
```elixir
# lib/gallformers/taxonomy.ex
def delete_taxonomy(%Taxonomy{} = taxonomy, opts \\ []) do
  reason = Keyword.get(opts, :reason)

  with :ok <- validate_dependencies(taxonomy),
       :ok <- validate_reason_if_required(taxonomy, reason),
       {:ok, deleted} <- do_delete(taxonomy, reason) do
    {:ok, deleted}
  end
end

defp validate_dependencies(%Taxonomy{id: id}) do
  cond do
    has_children?(id) ->
      {:error, {:has_children, count_children(id)}}

    has_species?(id) ->
      {:error, {:has_species, count_species(id)}}

    true ->
      :ok
  end
end

defp validate_reason_if_required(%{type: "family"}, nil) do
  {:error, :reason_required}
end
defp validate_reason_if_required(_, _), do: :ok

defp do_delete(taxonomy, reason) do
  custom = if reason, do: %{deletion_reason: reason}, else: %{}
  Repo.delete(taxonomy, ex_audit_custom: custom)
end
```

**Error handling:**
```elixir
case delete_taxonomy(taxonomy, reason: reason) do
  {:ok, _} ->
    {:noreply, put_flash(socket, :info, "Deleted")}

  {:error, {:has_children, count}} ->
    {:noreply, put_flash(socket, :error,
      "Cannot delete: has #{count} child genera. Reassign or delete them first.")}

  {:error, {:has_species, count}} ->
    {:noreply, put_flash(socket, :error,
      "Cannot delete: has #{count} associated species.")}

  {:error, :reason_required} ->
    {:noreply, put_flash(socket, :error,
      "Deletion reason required for Family-level taxonomy.")}

  {:error, %Ecto.Changeset{} = changeset} ->
    # Database RESTRICT caught something we missed
    {:noreply, assign(socket, :errors, translate_errors(changeset))}
end
```

### 4. UI Enhancements

**Deletion workflow:**
```heex
<.modal id="delete-genus-modal">
  <:title>Delete Genus: <%= @taxonomy.name %></:title>

  <.alert :if={@dependencies != []}>
    This genus has dependencies that must be handled first:

    <ul>
      <li :for={dep <- @dependencies}>
        <%= dep.count %> <%= dep.type %>
      </li>
    </ul>

    Choose an action:
    <.button phx-click="reassign">Reassign to another Genus</.button>
    <.button phx-click="show_children">Review and delete individually</.button>
  </.alert>

  <.simple_form :if={@dependencies == []} for={@form} phx-submit="confirm_delete">
    <.input
      field={@form[:reason]}
      type="textarea"
      label="Reason for deletion (required for accountability):"
      required
    />

    <:actions>
      <.button type="submit" class="danger">Delete</.button>
      <.button type="button" phx-click={hide_modal("delete-genus-modal")}>
        Cancel
      </.button>
    </:actions>
  </.simple_form>
</.modal>
```

---

## Migration Strategy

### Phase 1: Setup (No User Impact)

**1. Add ex_audit dependency**
- Add to mix.exs
- Run `mix deps.get`

**2. Create versions table**
- Generate migration
- Run `mix ecto.migrate`

**3. Configure ex_audit**
- Update Repo module
- Configure tracked schemas
- Add audit context plug

**4. Deploy**
- No user-facing changes yet
- Audit tracking begins silently

### Phase 2: Critical Cascade Protection

**For each critical foreign key:**

1. Create migration to rebuild table with RESTRICT
2. Test in development
3. Deploy during maintenance window (or zero-downtime with careful steps)

**Example migration:**
```elixir
defmodule Gallformers.Repo.Migrations.ProtectSpeciesDeletion do
  use Ecto.Migration

  def up do
    execute "PRAGMA foreign_keys = OFF"

    # Rebuild speciestaxonomy with RESTRICT
    create table(:speciestaxonomy_new, primary_key: false) do
      add :species_id, references(:species, on_delete: :restrict),
        null: false, primary_key: true
      add :taxonomy_id, references(:taxonomy, on_delete: :restrict),
        null: false, primary_key: true
    end

    execute "INSERT INTO speciestaxonomy_new SELECT * FROM speciestaxonomy"
    execute "DROP TABLE speciestaxonomy"
    execute "ALTER TABLE speciestaxonomy_new RENAME TO speciestaxonomy"

    # Recreate indexes
    create index(:speciestaxonomy, [:species_id])
    create index(:speciestaxonomy, [:taxonomy_id])

    execute "PRAGMA foreign_keys = ON"
    execute "PRAGMA foreign_key_check"
  end

  def down do
    # Reverse: rebuild with CASCADE
  end
end
```

### Phase 3: Application Validation

**For each protected entity type:**

1. Add dependency validation to context
2. Update LiveView delete handlers
3. Add UI for handling dependencies
4. Add deletion reason prompts for sensitive types

### Phase 4: Rollout

**Week 1:** Deploy audit tracking (silent)
**Week 2:** Deploy Phase 1 CASCADE → RESTRICT migrations
**Week 3:** Deploy validation + UI updates
**Week 4:** Monitor, gather feedback, iterate

---

## Restore Capability

### Design

Since cascades are prevented, restore is simpler than originally thought:

**Single record restore:**
```elixir
def restore_from_version(version_id) do
  version = Repo.get!(Version, version_id)

  # Deserialize the original record
  original_record = ExAudit.Tracking.deserialize_patch(version.patch)

  # Re-insert with original ID
  Repo.insert(original_record)
end
```

**No cascade restore needed** because records are never cascade-deleted!

---

## Testing Strategy

### Unit Tests

```elixir
describe "delete_taxonomy/1 with RESTRICT constraints" do
  test "prevents deletion when children exist" do
    genus = insert_genus_with_species(species_count: 5)

    assert {:error, {:has_species, 5}} = delete_taxonomy(genus)
    assert Repo.get(Taxonomy, genus.id) # Still exists
  end

  test "allows deletion when no dependencies" do
    genus = insert_genus()  # No species

    assert {:ok, _} = delete_taxonomy(genus)
    refute Repo.get(Taxonomy, genus.id)
  end

  test "creates audit version on successful delete" do
    genus = insert_genus()
    {:ok, deleted} = delete_taxonomy(genus, reason: "Test cleanup")

    version = Repo.one!(from v in Version,
      where: v.entity_schema == "taxonomy" and v.entity_id == ^genus.id)

    assert version.action == "deleted"
    assert version.deletion_reason == "Test cleanup"
  end
end
```

### Integration Tests

```elixir
test "race condition prevented by database", %{conn: conn} do
  genus = insert_genus()

  # Simulate concurrent operations
  task = Task.async(fn ->
    # Add species after check
    Process.sleep(10)
    insert_species(genus_id: genus.id)
  end)

  # Try to delete (will fail due to RESTRICT)
  assert {:error, _} = delete_taxonomy(genus)

  Task.await(task)
  assert Repo.get(Taxonomy, genus.id) # Still exists
  assert Repo.aggregate(Species, :count) == 1 # Species safe
end
```

### E2E Tests

```elixir
test "delete genus with dependencies shows helpful error", %{session: session} do
  genus = insert_genus_with_species(species_count: 3)

  session
  |> visit("/admin/taxonomy/#{genus.id}")
  |> click(Query.button("Delete"))
  |> assert_has(Query.text("has 3 associated species"))
  |> assert_has(Query.link("Reassign to another Genus"))
end
```

---

## Success Metrics

**Safety:**
- ✅ Zero accidental cascade deletes
- ✅ Zero race condition data loss
- ✅ 100% of deletes tracked in audit log

**Accountability:**
- ✅ Every deletion has user_id and timestamp
- ✅ Sensitive deletions have required reasons
- ✅ Audit log queryable by entity, user, time

**Team Confidence:**
- ✅ Team reports feeling safe to delete data
- ✅ Reduction in support requests about "how do I delete X"
- ✅ Reduction in manual backup restoration requests

**Technical:**
- ✅ All Phase 1 foreign keys have RESTRICT
- ✅ ex_audit capturing all CRUD operations
- ✅ Restore functionality tested and documented

---

## Open Questions

1. **Restore UI:** Should we build an admin UI for browsing/restoring versions, or keep it iex-only initially?
2. **Retention:** How long to keep audit records? Forever, or prune after N years?
3. **Phase 2 timing:** When to tackle gall characteristic cascades?
4. **Backup coordination:** How does this interact with Litestream backups?

---

## Next Steps

1. ✅ Design complete (this document)
2. ⏭️ Create detailed implementation plan
3. ⏭️ Generate migrations for Phase 1 constraints
4. ⏭️ Implement ex_audit setup
5. ⏭️ Build dependency validation
6. ⏭️ Update UI for deletion workflows
7. ⏭️ Write tests
8. ⏭️ Deploy in phases

---

## Appendix: CASCADE Constraint Inventory

### Critical (Phase 1)
- `speciestaxonomy.species_id → species`
- `speciestaxonomy.taxonomy_id → taxonomy`
- `taxonomy.parent_id → taxonomy`
- `image.species_id → species`
- `gallspecies.species_id → species`
- `host.gall_species_id → species`
- `host.host_species_id → species`

### Medium (Phase 2)
- `gallalignment.gall_id → gall`
- `gallcells.gall_id → gall`
- `gallcolor.gall_id → gall`
- `gallform.gall_id → gall`
- `galllocation.gall_id → gall`
- `gallseason.gall_id → gall`
- `gallshape.gall_id → gall`
- `galltexture.gall_id → gall`
- `gallwalls.gall_id → gall`

### Review (Phase 3)
- All other CASCADE constraints (20 remaining)
