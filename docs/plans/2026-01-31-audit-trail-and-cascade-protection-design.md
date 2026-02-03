# Audit Trail and Cascade Delete Protection - Design Document

**Date:** 2026-01-31 (Initial), 2026-02-01 (Comprehensive CASCADE Analysis)
**Status:** Comprehensive CASCADE analysis complete - Design updated - Ready for schema refactor planning
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

**Database structure:**
- **Critical data tables:** `gall`, `species`, `host`, `source`, `taxonomy`
- **Join tables (many-to-many):** `gallspecies`, `speciessource`, `speciesplace`, `speciestaxonomy`, etc.
- **Lookup tables:** `place`, `alias`, `abundance`, gall trait tables (color, shape, etc.)

**Actual problems identified:**
1. `taxonomy.parent_id → taxonomy (CASCADE)` - Deleting parent deletes child taxa
2. `image.source_id → source (CASCADE)` - Should SET NULL instead (lose metadata, keep image)
3. No application-level validation prevents deleting entities with dependencies

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
2. **Targeted CASCADE fixes** - Fix 2 specific dangerous cascades
3. **Application validation** - Prevent deleting entities with dependencies

### Why This Works

**Most cascades are actually correct:**
- Join table cascades (speciestaxonomy, gallspecies, etc.) are cleanup ✅
- Gall trait cascades (gallcolor, gallshape, etc.) are cleanup ✅
- `image.species_id → species CASCADE` is intentional (with S3 cleanup) ✅

**Cascades requiring fixes (updated 2026-02-01):**
1. `taxonomy.parent_id → taxonomy` - Change to RESTRICT (prevent deleting parent with children)
2. `image.source_id → source` - Change to RESTRICT (prevent deletion if images reference source) - **Updated from original SET NULL plan**
3. `speciestaxonomy.taxonomy_id → taxonomy` - Change to RESTRICT (force handling species before taxonomy deletion)
4. `taxonomy.type_id → taxontype` - Change to RESTRICT (prevent deletion of types in use)

**Application validation provides safety:**
- Shows dependencies before deletion (e.g., "This Genus has 25 Species")
- Forces user to handle dependencies explicitly
- Requires deletion reasons for critical entities
- Prevents race conditions (user checks, database enforces)

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

**Updated analysis (2026-02-01) - 4 database changes needed:**

**1. `taxonomy.parent_id → taxonomy`**
```sql
-- Change from CASCADE to RESTRICT
-- Prevents: Delete Family → cascade delete child Genera → cascade delete all Species
-- Critical protection against catastrophic data loss
```

**2. `image.source_id → source`**
```sql
-- Change from CASCADE to RESTRICT (updated from original SET NULL plan)
-- Prevents: Delete source → cascade delete images
-- Behavior: Blocks deletion; user must reassign images or delete them first
```

**3. `speciestaxonomy.taxonomy_id → taxonomy`**
```sql
-- Change from CASCADE to RESTRICT
-- Prevents: Delete taxonomy → orphan species taxonomic classifications
-- Forces: Explicit reassignment or deletion of species before taxonomy deletion
```

**4. `taxonomy.type_id → taxontype`**
```sql
-- Add RESTRICT constraint
-- Prevents: Delete taxonomy type (e.g., "genus") while records of that type exist
-- Safety: Fundamental classification data protected
```

**All other cascades are correct and should remain:**
- ✅ Join table cascades (cleanup relationships when either side deleted)
- ✅ Gall trait cascades (cleanup characteristics)
- ✅ `image.species_id → species CASCADE` (intentional, with S3 cleanup)
- ✅ Alias cascades (two-level from owner, one-level from alias)
- ✅ Lookup table SET NULL (abundance, detachable, walls, cells, form)

**See Appendix B for complete cascade constraint analysis.**

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

### Phase 2: Fix 2 Dangerous Cascades

**Migration 1: taxonomy.parent_id RESTRICT**
```elixir
defmodule Gallformers.Repo.Migrations.ProtectTaxonomyHierarchy do
  use Ecto.Migration

  def up do
    execute "PRAGMA foreign_keys = OFF"

    # Rebuild taxonomy with RESTRICT on parent_id
    create table(:taxonomy_new) do
      add :name, :string, null: false
      add :description, :string, default: ""
      add :type, :string, null: false
      add :parent_id, references(:taxonomy_new, on_delete: :restrict)
    end

    execute "INSERT INTO taxonomy_new SELECT * FROM taxonomy"
    execute "DROP TABLE taxonomy"
    execute "ALTER TABLE taxonomy_new RENAME TO taxonomy"

    # Recreate indexes
    create index(:taxonomy, [:parent_id])
    create unique_index(:taxonomy, [:name, :type])

    execute "PRAGMA foreign_keys = ON"
    execute "PRAGMA foreign_key_check"
  end
end
```

**Migration 2: image.source_id RESTRICT**
```elixir
defmodule Gallformers.Repo.Migrations.ImageSourceRestrict do
  use Ecto.Migration

  def up do
    execute "PRAGMA foreign_keys = OFF"

    # Rebuild image with RESTRICT on source_id (updated from original SET NULL plan)
    create table(:image_new) do
      add :species_id, references(:species, on_delete: :cascade), null: false
      add :source_id, references(:source, on_delete: :restrict)
      # ... other columns
    end

    execute "INSERT INTO image_new SELECT * FROM image"
    execute "DROP TABLE image"
    execute "ALTER TABLE image_new RENAME TO image"

    # Recreate indexes
    create index(:image, [:species_id])
    create index(:image, [:source_id])

    execute "PRAGMA foreign_keys = ON"
    execute "PRAGMA foreign_key_check"
  end
end
```

**Migration 3: speciestaxonomy.taxonomy_id RESTRICT**
```elixir
defmodule Gallformers.Repo.Migrations.SpeciesTaxonomyRestrict do
  use Ecto.Migration

  def up do
    execute "PRAGMA foreign_keys = OFF"

    # Rebuild speciestaxonomy with RESTRICT on taxonomy_id
    create table(:speciestaxonomy_new) do
      add :species_id, references(:species, on_delete: :cascade), null: false
      add :taxonomy_id, references(:taxonomy, on_delete: :restrict), null: false
      # ... other columns
    end

    execute "INSERT INTO speciestaxonomy_new SELECT * FROM speciestaxonomy"
    execute "DROP TABLE speciestaxonomy"
    execute "ALTER TABLE speciestaxonomy_new RENAME TO speciestaxonomy"

    # Recreate indexes
    create index(:speciestaxonomy, [:species_id])
    create index(:speciestaxonomy, [:taxonomy_id])
    create unique_index(:speciestaxonomy, [:species_id, :taxonomy_id])

    execute "PRAGMA foreign_keys = ON"
    execute "PRAGMA foreign_key_check"
  end
end
```

**Migration 4: taxonomy.type_id RESTRICT**
```elixir
defmodule Gallformers.Repo.Migrations.TaxonomyTypeRestrict do
  use Ecto.Migration

  def up do
    execute "PRAGMA foreign_keys = OFF"

    # Rebuild taxonomy with RESTRICT on type_id
    create table(:taxonomy_new) do
      add :name, :string, null: false
      add :description, :string, default: ""
      add :type_id, references(:taxontype, on_delete: :restrict), null: false
      add :parent_id, references(:taxonomy_new, on_delete: :restrict)
      # ... other columns
    end

    execute "INSERT INTO taxonomy_new SELECT * FROM taxonomy"
    execute "DROP TABLE taxonomy"
    execute "ALTER TABLE taxonomy_new RENAME TO taxonomy"

    # Recreate indexes
    create index(:taxonomy, [:parent_id])
    create index(:taxonomy, [:type_id])
    create unique_index(:taxonomy, [:name, :type_id])

    execute "PRAGMA foreign_keys = ON"
    execute "PRAGMA foreign_key_check"
  end
end
```

### Phase 3: Application Validation

**Add dependency validation for critical tables:**

- Taxonomy (Genus, Family, Section)
- Species
- Gall
- Host
- Source

**UI enhancements:**
- Dependency warning screens
- Deletion reason prompts
- "Reassign or delete children first" workflows

### Phase 4: Rollout

**Week 1:** Deploy ex_audit (silent, starts tracking)
**Week 2:** Deploy 2 CASCADE fix migrations
**Week 3:** Deploy application validation + UI
**Week 4:** Monitor, gather feedback

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
- ✅ 2 dangerous CASCADE constraints fixed
- ✅ ex_audit capturing all CRUD operations
- ✅ Application validation for critical deletes

---

## Open Questions

1. **Restore UI:** Should we build an admin UI for browsing/restoring versions, or keep it iex-only initially?
2. **Retention:** How long to keep audit records? Forever, or prune after N years?
3. **Backup coordination:** How does this interact with Litestream backups?
4. **Performance:** Will audit logging impact performance on high-volume operations?

---

## Next Steps

1. ✅ Design complete (this document)
2. ⏭️ Create detailed implementation plan (use superpowers:writing-plans)
3. ⏭️ Write migrations for 2 CASCADE fixes
4. ⏭️ Implement ex_audit setup
5. ⏭️ Build dependency validation
6. ⏭️ Update UI for deletion workflows
7. ⏭️ Write tests
8. ⏭️ Deploy in phases

---

## Appendix A: Domain Model Context

### Critical Understanding: Species, Galls, and Hosts

**Domain model:**
- `species` table = Base entity for ALL organisms (both gall-forming species AND host plants)
- `gall` table = Additional properties for gall-forming species (linked via `gallspecies` 1:1)
- `host` table = **Misnamed** - actually represents the `gallhost` relationship (which gall affects which host plant)
- Both galls and hosts are entries in the `species` table

**UI reality:**
- Users delete **galls** (species with gall properties) from the UI
- Users delete **hosts** (species that are plants) from the UI
- Users NEVER delete "species" directly - it only happens as a cascade from gall/host deletion

**Deletion flow:**
```
User deletes GALL →
  1. Delete gall record (extra properties)
  2. CASCADE delete gallspecies association (1:1 link)
  3. CASCADE delete species record (gall and species are tightly bound)
  4. CASCADE delete speciestaxonomy, speciessource, speciesplace, image (from species cascade)
  5. CASCADE delete host relationships (gall↔host)
```

**Verified schema facts:**
- `gallspecies` is currently many-to-many but behaves as 1:1 (verified via query: all relationships are 1:1)
- **Schema refactor consideration:** Should be a simple FK `gall.species_id → species`

---

## Appendix B: Complete CASCADE Constraint Analysis

**Date analyzed:** 2026-02-01
**Status:** Comprehensive review completed for schema refactor planning

### Summary of Changes Required

| Foreign Key | Current | Required | Rationale |
|-------------|---------|----------|-----------|
| `taxonomy.parent_id → taxonomy` | CASCADE | **RESTRICT** | Prevent catastrophic deletion (Family → Genera → Species) |
| `image.source_id → source` | CASCADE | **RESTRICT** | Prevent image loss when source deleted (updated from original SET NULL plan) |
| `speciestaxonomy.taxonomy_id → taxonomy` | CASCADE | **RESTRICT** | Force explicit handling of species before taxonomy deletion |
| `taxonomy.type_id → taxontype` | ??? | **RESTRICT** | Prevent deletion of taxonomy types in use |
| `placeplace.parent_id → place` | ??? | **CASCADE** | Geographic hierarchy can cascade delete |

All other constraints remain CASCADE or SET NULL as designed.

---

### Detailed Constraint Decisions

#### SPECIES Relationships

**Domain context:** Species are deleted indirectly (via gall or host deletion), never directly from UI.

| Foreign Key | Direction | Decision | Rationale |
|-------------|-----------|----------|-----------|
| `image.species_id → species` | Species deleted | **CASCADE** | Images belong to species; includes S3 cleanup. Intentional data loss. |
| `speciestaxonomy.species_id → species` | Species deleted | **CASCADE** | Cleanup join table. Species no longer exists, associations meaningless. |
| `speciestaxonomy.taxonomy_id → taxonomy` | Taxonomy deleted | **RESTRICT** ⚠️ | **CHANGED:** Prevent taxonomy deletion if species are using it. Forces explicit handling. |
| `speciessource.species_id → species` | Species deleted | **CASCADE** | Cleanup join table. |
| `speciessource.source_id → source` | Source deleted | **CASCADE** | Cleanup join table only. Species remain (just lose source association). |
| `speciesplace.species_id → species` | Species deleted | **CASCADE** | Cleanup join table. |
| `speciesplace.place_id → place` | Place deleted | **CASCADE** | Cleanup join table only. Species remain. |
| `gallspecies.species_id → species` | Species deleted | **CASCADE** | Cleanup join table (gall ↔ species link). |
| `host.species_id → species` | Gall species deleted | **CASCADE** | Cleanup gall↔host relationships when gall is deleted. |
| `host.host_species_id → species` | Host plant deleted | **CASCADE** | Cleanup gall↔host relationships when host plant is deleted. |
| `aliasspecies.species_id → species` | Species deleted | **CASCADE** (two-level) | Cascade delete join table + alias records. Alias is meaningless without species. |
| `aliasspecies.alias_id → alias` | Alias deleted (SQL) | **CASCADE** (one-level) | Cleanup join table only. Species remain. |
| `species.abundance_id → abundance` | Abundance deleted (migration) | **SET NULL** | Species lose abundance classification but remain. Lookup table change. |

#### GALL Relationships

**Domain context:** Galls are deleted from UI. Deleting gall cascades to delete its species (tightly bound).

| Foreign Key | Direction | Decision | Rationale |
|-------------|-----------|----------|-----------|
| `gall.detachable_id → detachable` | Detachable deleted (migration) | **SET NULL** | Gall loses detachability classification. Lookup table change. |
| `gall.walls_id → walls` | Walls deleted (migration) | **SET NULL** | Gall loses walls classification. Lookup table change. |
| `gall.cells_id → cells` | Cells deleted (migration) | **SET NULL** | Gall loses cells classification. Lookup table change. |
| `gall.form_id → form` | Form deleted (migration) | **SET NULL** | Gall loses form classification. Lookup table change. |
| `gallcolor.gall_id → gall` | Gall deleted | **CASCADE** | Cleanup trait association. |
| `gallcolor.color_id → color` | Color deleted (migration) | **CASCADE** | Cleanup associations. Fixed lookup data (migration-only changes). |
| `gallshape.gall_id → gall` | Gall deleted | **CASCADE** | Cleanup trait association. |
| `gallshape.shape_id → shape` | Shape deleted (migration) | **CASCADE** | Cleanup associations. Fixed lookup data. |
| `galltexture.gall_id → gall` | Gall deleted | **CASCADE** | Cleanup trait association. |
| `galltexture.texture_id → texture` | Texture deleted (migration) | **CASCADE** | Cleanup associations. Fixed lookup data. |
| `gallalign.gall_id → gall` | Gall deleted | **CASCADE** | Cleanup trait association. |
| `gallalign.alignment_id → alignment` | Alignment deleted (migration) | **CASCADE** | Cleanup associations. Fixed lookup data. |
| `gallloc.gall_id → gall` | Gall deleted | **CASCADE** | Cleanup trait association. |
| `gallloc.location_id → location` | Location deleted (migration) | **CASCADE** | Cleanup associations. Fixed lookup data. |
| `gallseason.gall_id → gall` | Gall deleted | **CASCADE** | Cleanup trait association. |
| `gallseason.season_id → season` | Season deleted (migration) | **CASCADE** | Cleanup associations. Fixed lookup data. |
| `gallwalls.gall_id → gall` | Gall deleted | **CASCADE** | Cleanup trait association. |
| `gallcells.gall_id → gall` | Gall deleted | **CASCADE** | Cleanup trait association. |
| `gallform.gall_id → gall` | Gall deleted | **CASCADE** | Cleanup trait association. |

**Pattern:** All gall trait join tables CASCADE on both sides. Traits are fixed lookup data (migration-only).

#### TAXONOMY Relationships

**Domain context:** Taxonomy forms a parent-child hierarchy (Kingdom → Phylum → ... → Genus → Species).

| Foreign Key | Direction | Decision | Rationale |
|-------------|-----------|----------|-----------|
| `taxonomy.parent_id → taxonomy` | Parent deleted | **RESTRICT** ⚠️ | **CRITICAL FIX:** Prevent catastrophic cascade (e.g., delete Family → all Genera → all Species). |
| `speciestaxonomy.taxonomy_id → taxonomy` | Taxonomy deleted | **RESTRICT** ⚠️ | **CHANGED:** Force handling of species before taxonomy deletion. Prevents orphaning species. |
| `taxonomyalias.taxonomy_id → taxonomy` | Taxonomy deleted | **CASCADE** (two-level) | Cascade delete join table + alias records. Alias meaningless without taxonomy. |
| `taxonomyalias.alias_id → alias` | Alias deleted (SQL) | **CASCADE** (one-level) | Cleanup join table only. Taxonomy remains. |
| `taxonomy.type_id → taxontype` | Taxontype deleted (migration) | **RESTRICT** ⚠️ | **NEW:** Prevent deletion of taxonomy types (family, genus, etc.) if in use. |

#### SOURCE Relationships

| Foreign Key | Direction | Decision | Rationale |
|-------------|-----------|----------|-----------|
| `image.source_id → source` | Source deleted | **RESTRICT** ⚠️ | **CHANGED FROM PLAN:** Prevent source deletion if images reference it. Forces explicit handling. Original plan was SET NULL. |
| `speciessource.source_id → source` | Source deleted | **CASCADE** | Cleanup join table only. Species remain (just lose source association). |

#### IMAGE Relationships

| Foreign Key | Direction | Decision | Rationale |
|-------------|-----------|----------|-----------|
| `image.species_id → species` | Species deleted | **CASCADE** | Images belong to species. Includes S3 cleanup. Intentional data loss. |
| `image.source_id → source` | Source deleted | **RESTRICT** ⚠️ | Prevent image loss. Must handle images before deleting source. |

#### PLACE Relationships

| Foreign Key | Direction | Decision | Rationale |
|-------------|-----------|----------|-----------|
| `speciesplace.place_id → place` | Place deleted | **CASCADE** | Cleanup join table only. Species remain. |
| `placeplace.parent_id → place` | Parent place deleted | **CASCADE** | Geographic hierarchy (State → County → City). OK to cascade delete children. |

#### ALIAS Relationships

**Pattern:** Aliases have asymmetric cascades (two-level from owner, one-level from alias).

| Foreign Key | Direction | Decision | Rationale |
|-------------|-----------|----------|-----------|
| `aliasspecies.species_id → species` | Species deleted | **CASCADE** (two-level) | Delete join table → delete alias. Alias meaningless without species. |
| `aliasspecies.alias_id → alias` | Alias deleted (SQL) | **CASCADE** (one-level) | Delete join table only. Species remains. |
| `taxonomyalias.taxonomy_id → taxonomy` | Taxonomy deleted | **CASCADE** (two-level) | Delete join table → delete alias. Alias meaningless without taxonomy. |
| `taxonomyalias.alias_id → alias` | Alias deleted (SQL) | **CASCADE** (one-level) | Delete join table only. Taxonomy remains. |

---

### Open Investigation Items

**Discovered during analysis:**

1. **`taxonomytaxonomy` table** - May be legacy artifact unused since `taxonomy.parent_id` exists. Needs investigation.
   - If unused: Consider dropping in schema refactor
   - If used: Document purpose and cascade behavior

2. **`gallspecies` 1:1 behavior** - Currently many-to-many table but verified to only have 1:1 relationships.
   - **Schema refactor opportunity:** Replace with `gall.species_id → species` FK
   - Would simplify schema and deletion logic

---

### Key Decisions Different from Original Plan

| Original Plan | Actual Decision | Rationale |
|---------------|-----------------|-----------|
| `image.source_id → source`: SET NULL | **RESTRICT** | Stronger protection. Force explicit image handling before source deletion. |
| Only 2 cascades need fixing | **3+ cascades need fixing** | Added `speciestaxonomy.taxonomy_id`, `taxonomy.type_id`, and reconsidered join table behavior. |

---

### Schema Refactor Considerations

**Issues identified for future schema work:**

1. **`host` table misnamed** → Should be `gallhost` (represents relationship, not host entity)
2. **`gallspecies` unnecessary join table** → Could be simple FK `gall.species_id → species`
3. **`taxonomytaxonomy` potentially unused** → Investigate and possibly remove
4. **Asymmetric alias cascades are confusing** → Consider alternative design where aliases are owned by species/taxonomy with FK

**This cascade analysis is foundational for schema refactor planning.**
