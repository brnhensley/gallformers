# Undescribed/Completeness Separation — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Separate taxonomic "undescribed" status from entry "incomplete" status, promote gallformers code to a real data field, and clean up the former_undescribed alias infrastructure.

**Architecture:** Remove the source-check branch from `compute_undescribed_lock/2`. Add a parallel `compute_datacomplete_lock/1` that gates datacomplete on sources and undescribed status. Add `gallformers_code` string field (unique) to `gall_traits` and read it directly instead of deriving from names/aliases. Remove all `former_undescribed` alias machinery.

**Tech Stack:** Elixir/Phoenix LiveView, Ecto with SQLite, TDD with ExUnit.

**Working on:** `main` branch directly (no worktree).

**Design doc:** `docs/plans/2026-02-15-undescribed-completeness-separation-design.md`
**Data audit:** `docs/plans/Triaging the state of Gall species data.md`

---

## Task 1: Data Audit — COMPLETE

Data audit is done. Results documented in the triage doc. Three action items sent to reviewers, feedback due Tuesday 2026-02-18. Code tasks 2-9 can proceed now. Data migration (task 10) is blocked until feedback is in.

---

## Task 2: Add `gallformers_code` Field to GallTraits Schema

**Files:**
- Modify: `lib/gallformers/galls/gall_traits.ex`
- Create: migration via `mix ecto.gen.migration add_gallformers_code_to_gall_traits`

**Step 1: Generate migration**

```bash
mix ecto.gen.migration add_gallformers_code_to_gall_traits
```

**Step 2: Write the migration**

In the generated file:

```elixir
defmodule Gallformers.Repo.Migrations.AddGallformersCodeToGallTraits do
  use Ecto.Migration

  def change do
    alter table(:gall_traits) do
      add :gallformers_code, :string
    end

    create unique_index(:gall_traits, [:gallformers_code],
      where: "gallformers_code IS NOT NULL",
      name: :gall_traits_gallformers_code_unique
    )
  end
end
```

**Step 3: Add field to schema**

Modify `lib/gallformers/galls/gall_traits.ex`:

- Add `:gallformers_code` to `@optional_fields` (line 14)
- Add `field :gallformers_code, :string` to schema (after line 28)
- Add `gallformers_code: String.t() | nil` to `@type t` (after line 19)
- Add `unique_constraint(:gallformers_code, name: :gall_traits_gallformers_code_unique)` to changeset

**Step 4: Run migration**

```bash
mix ecto.migrate
```

**Step 5: Verify compilation**

```bash
mix compile --warnings-as-errors
```

**Step 6: Commit**

```
Add gallformers_code field to gall_traits schema

Stores the iNaturalist observation linking code as a proper data field
instead of deriving it from the species name. Unique index enforced
when non-null.
```

---

## Task 3: Modify Undescribed Lock — Remove Source Check

**Files:**
- Modify: `lib/gallformers/galls.ex:669-682`
- Modify: `test/gallformers/galls_test.exs:361-423`

**Step 1: Update the test — change "locked when no sources" to expect unlocked**

In `test/gallformers/galls_test.exs`, the test at line 379 ("locked when species has no sources") should be changed to expect `{false, nil}`:

```elixir
test "unlocked when species has no sources but real genus" do
  {:ok, species} =
    Repo.insert(%Species{
      name: "Locktest sp",
      taxoncode: "gall",
      datacomplete: false
    })

  taxonomy = %Lineage{genus: %Genus{name: "Locktest"}}
  assert {false, nil} = Galls.compute_undescribed_lock(taxonomy, species.id)
end
```

**Step 2: Run test to verify it fails**

```bash
mix test test/gallformers/galls_test.exs --only describe:"compute_undescribed_lock/2"
```

Expected: FAIL — the old code still locks on no sources.

**Step 3: Update `compute_undescribed_lock/2`**

In `lib/gallformers/galls.ex`, replace lines 669-682:

```elixir
@spec compute_undescribed_lock(Gallformers.Taxonomy.Lineage.t() | nil, integer() | nil) ::
        {boolean(), String.t() | nil}
def compute_undescribed_lock(taxonomy, _species_id \\ nil) do
  genus_name = taxonomy && taxonomy.genus && taxonomy.genus.name

  if Gallformers.Taxonomy.placeholder_genus_name?(genus_name) do
    {true, "Undescribed is required for species with unknown genus."}
  else
    {false, nil}
  end
end
```

Note: `species_id` parameter is kept (with underscore) for backward compatibility since callers pass it.

**Step 4: Run tests**

```bash
mix test test/gallformers/galls_test.exs --only describe:"compute_undescribed_lock/2"
```

Expected: all pass.

**Step 5: Run full test suite**

```bash
mix test
```

**Step 6: Commit**

```
Remove source requirement from undescribed lock

Undescribed status is now purely taxonomic: only locked for species
under placeholder (Unknown) genera. Missing sources are handled by
the datacomplete lock instead.
```

---

## Task 4: Add `compute_datacomplete_lock/1`

**Files:**
- Modify: `lib/gallformers/galls.ex` (add function near `compute_undescribed_lock`)
- Modify: `test/gallformers/galls_test.exs` (add new describe block)

**Step 1: Write failing tests**

Add to `test/gallformers/galls_test.exs`, after the `compute_undescribed_lock` describe block:

```elixir
describe "compute_datacomplete_lock/1" do
  test "locked when species has no sources" do
    {:ok, species} =
      Repo.insert(%Species{
        name: "Nolock sp",
        taxoncode: "gall",
        datacomplete: false
      })

    {true, reason} = Galls.compute_datacomplete_lock(species.id)
    assert reason =~ "source is required"
  end

  test "locked when species is undescribed" do
    {:ok, species} =
      Repo.insert(%Species{
        name: "Undesc sp",
        taxoncode: "gall",
        datacomplete: false
      })

    {:ok, _} = Galls.create_gall_traits(species.id)
    Galls.update_gall_properties(species.id, %{undescribed: true})

    # Add a source so we isolate the undescribed check
    {:ok, source} =
      Gallformers.Sources.create_source(%{
        title: "Test Source",
        author: "Author",
        pubyear: "2020",
        link: "http://example.com",
        citation: "Test citation",
        license: "CC BY"
      })

    Gallformers.Sources.create_species_source(%{
      species_id: species.id,
      source_id: source.id
    })

    {true, reason} = Galls.compute_datacomplete_lock(species.id)
    assert reason =~ "undescribed"
  end

  test "unlocked when species has sources and is described" do
    {:ok, species} =
      Repo.insert(%Species{
        name: "Haslock sp",
        taxoncode: "gall",
        datacomplete: false
      })

    {:ok, source} =
      Gallformers.Sources.create_source(%{
        title: "Test Source",
        author: "Author",
        pubyear: "2020",
        link: "http://example.com",
        citation: "Test citation",
        license: "CC BY"
      })

    Gallformers.Sources.create_species_source(%{
      species_id: species.id,
      source_id: source.id
    })

    assert {false, nil} = Galls.compute_datacomplete_lock(species.id)
  end

  test "unlocked for nil species_id" do
    assert {false, nil} = Galls.compute_datacomplete_lock(nil)
  end
end
```

**Step 2: Run tests to verify they fail**

```bash
mix test test/gallformers/galls_test.exs --only describe:"compute_datacomplete_lock/1"
```

Expected: FAIL — function doesn't exist.

**Step 3: Implement `compute_datacomplete_lock/1`**

Add to `lib/gallformers/galls.ex`, after `compute_undescribed_lock`:

```elixir
@doc """
Computes whether the datacomplete checkbox should be locked and why.

A gall's datacomplete flag is locked to `false` when:
- The species has no sources linked — a source is required for completeness
- The gall is marked undescribed — undescribed species are by definition incomplete

Returns `{locked?, reason}` where reason is a string explaining the lock, or nil if unlocked.
"""
@spec compute_datacomplete_lock(integer() | nil) :: {boolean(), String.t() | nil}
def compute_datacomplete_lock(nil), do: {false, nil}

def compute_datacomplete_lock(species_id) do
  cond do
    not Gallformers.Sources.has_sources?(species_id) ->
      {true, "A source is required to mark a gall as data complete."}

    undescribed?(species_id) ->
      {true, "An undescribed gall cannot be marked as data complete."}

    true ->
      {false, nil}
  end
end
```

**Step 4: Run tests**

```bash
mix test test/gallformers/galls_test.exs --only describe:"compute_datacomplete_lock/1"
```

Expected: all pass.

**Step 5: Commit**

```
Add compute_datacomplete_lock to gate completeness on sources and undescribed

Datacomplete is locked when a gall has no sources or is marked
undescribed. An undescribed species by definition has incomplete data.
```

---

## Task 5: Wire Datacomplete Lock into Gall Admin Form

**Files:**
- Modify: `lib/gallformers_web/live/admin/gall_live/form.ex`

**Step 1: Add default assigns**

Near lines 117-118 (after the undescribed lock assigns), add:

```elixir
|> assign(:datacomplete_locked, false)
|> assign(:datacomplete_lock_reason, nil)
```

**Step 2: Add `apply_datacomplete_lock/2` helper**

After the existing `apply_undescribed_lock/3` function (around line 684), add:

```elixir
defp apply_datacomplete_lock(socket, species_id \\ nil) do
  {locked?, reason} = Galls.compute_datacomplete_lock(species_id)

  socket
  |> assign(:datacomplete_locked, locked?)
  |> assign(:datacomplete_lock_reason, reason)
end
```

**Step 3: Call it everywhere `apply_undescribed_lock` is called**

There are 4 call sites. After each `apply_undescribed_lock` call, pipe into `apply_datacomplete_lock`:

- Line 191: add `|> apply_datacomplete_lock()`
- Line 228: add `|> apply_datacomplete_lock()`
- Line 300: add `|> apply_datacomplete_lock(species_id)`
- Line 630: add `|> apply_datacomplete_lock(species_id)`

**Step 4: Update the template — lock the datacomplete checkbox**

Replace the datacomplete checkbox section (around lines 1132-1136) from the `.input` component to a manual checkbox with lock behavior matching the undescribed pattern:

```heex
<div>
  <label class={[
    "flex items-center gap-2",
    if(@datacomplete_locked, do: "cursor-not-allowed", else: "cursor-pointer")
  ]}>
    <input
      type="checkbox"
      name={@form[:datacomplete].name}
      value="true"
      checked={Phoenix.HTML.Form.normalize_value("checkbox", @form[:datacomplete].value)}
      disabled={@datacomplete_locked}
      class="rounded border-gray-300 text-gf-maroon focus:ring-gf-maroon disabled:opacity-50"
    />
    <span class="text-sm text-gray-700">
      All sources containing unique information relevant to this gall have been added and are reflected in its associated data.
    </span>
  </label>
  <p :if={@datacomplete_lock_reason} class="text-amber-600 text-xs mt-1 ml-6">
    {@datacomplete_lock_reason}
  </p>
</div>
```

**Step 5: Force datacomplete=false on save when locked**

In the `save` event handler (around line 404), after building `params`, add:

```elixir
params =
  if socket.assigns[:datacomplete_locked] do
    Map.put(params, "datacomplete", "false")
  else
    params
  end
```

**Step 6: Verify compilation and run tests**

```bash
mix compile --warnings-as-errors && mix test
```

**Step 7: Commit**

```
Wire datacomplete lock into gall admin form

Datacomplete checkbox is now disabled with amber reason text when
the gall has no sources or is undescribed, mirroring the undescribed
lock pattern.
```

---

## Task 6: Add Gallformers Code to Gall Admin Form

**Files:**
- Modify: `lib/gallformers_web/live/admin/gall_live/form.ex`
- Modify: `lib/gallformers/galls.ex` (update `create_gall_with_associations`, `update_gall_with_associations`)

**Step 1: Add gallformers_code to save params**

In `save_gall/3` for `:new` (around line 709), add to `create_params`:

```elixir
gallformers_code: socket.assigns[:gallformers_code]
```

In `save_gall/3` for `:edit` (around line 740), add to `update_params`:

```elixir
gallformers_code: socket.assigns[:gallformers_code]
```

**Step 2: Update `update_gall_properties` calls**

In `lib/gallformers/galls.ex`, the `update_gall_properties` call in `create_gall_with_associations` (line 841) becomes:

```elixir
update_gall_properties(species.id, %{
  detachable: params.detachable,
  undescribed: params.undescribed,
  gallformers_code: params[:gallformers_code]
})
```

Same for `update_gall_with_associations` (line 890).

**Step 3: Add assign, event handler, and load logic**

In the form's default assigns setup, add:

```elixir
|> assign(:gallformers_code, nil)
```

In `load_gall_for_edit`, fetch the gallformers_code from gall_traits:

```elixir
gall_traits = Repo.get(Gallformers.Galls.GallTraits, species_id)
```

Then assign it:

```elixir
|> assign(:gallformers_code, gall_traits && gall_traits.gallformers_code)
```

Add event handler:

```elixir
def handle_event("update_gallformers_code", %{"value" => value}, socket) do
  {:noreply, socket |> assign(:gallformers_code, value) |> mark_dirty()}
end
```

**Step 4: Add template input**

Near the undescribed checkbox section (around line 1157), add:

```heex
<div :if={@undescribed || @gallformers_code not in [nil, ""]} class="mt-2">
  <label class="block text-sm font-medium text-gray-700 mb-1">Gallformers Code</label>
  <input
    type="text"
    name="gallformers_code"
    value={@gallformers_code}
    phx-change="update_gallformers_code"
    phx-debounce="300"
    placeholder="e.g. q-lobata-leaf-blister"
    class="w-full px-3 py-2 border border-gray-300 rounded text-sm focus:ring-gf-maroon focus:border-gf-maroon"
  />
  <p class="text-gray-500 text-xs mt-1">
    Used for iNaturalist observation linking. Auto-populated for new undescribed galls.
  </p>
</div>
```

**Step 5: Verify compilation and run tests**

```bash
mix compile --warnings-as-errors && mix test
```

**Step 6: Commit**

```
Add gallformers_code field to gall admin form

Editable text input displayed when gall is undescribed or has an
existing code. Persisted via update_gall_properties.
```

---

## Task 7: Update Undescribed Creation Flow

**Files:**
- Modify: `lib/gallformers_web/live/admin/gall_live/undescribed.ex`
- Modify: `lib/gallformers_web/live/admin/gall_live/form.ex`

**Step 1: Pass gallformers_code through the undescribed flow**

In `undescribed.ex`, the `continue` event handler (line 373) navigates with query params. Add the gallformers code derived from the epithet:

```elixir
# After line 375: name = String.trim(socket.assigns.name)
gallformers_code = TaxonName.parse(name).epithet

query_string =
  URI.encode_query(%{
    species_name: name,
    host_id: to_string(socket.assigns.selected_host.id),
    undescribed: "true",
    gallformers_code: gallformers_code
  })
```

**Step 2: Read gallformers_code in the form's undescribed init**

In `form.ex`, the function that handles undescribed flow params (around line 195) needs to assign the gallformers_code:

```elixir
|> assign(:gallformers_code, params["gallformers_code"])
```

**Step 3: Verify compilation and run tests**

```bash
mix compile --warnings-as-errors && mix test
```

**Step 4: Commit**

```
Pre-populate gallformers_code in undescribed creation flow
```

---

## Task 8: Update Public Gall Page Display

**Files:**
- Modify: `lib/gallformers_web/live/gall_live.ex`

**Step 1: Replace `compute_gallformers_code/3` with direct field read**

Around line 103-104, replace:

```elixir
{gallformers_code, former_undescribed_alias} =
  compute_gallformers_code(aliases, gall, taxonomy)
```

With:

```elixir
gall_traits = Gallformers.Repo.get(Gallformers.Galls.GallTraits, gall_id)
gallformers_code = gall_traits && gall_traits.gallformers_code
```

**Step 2: Update assigns**

Remove the `former_undescribed_name` assign (line 149). Remove the `former_undescribed_alias` variable.

**Step 3: Simplify scientific_aliases filter**

Lines 100-101, change from:

```elixir
scientific_aliases =
  Enum.filter(aliases, &(&1.type not in ["common", "former_undescribed"]))
```

To:

```elixir
scientific_aliases =
  Enum.filter(aliases, &(&1.type != "common"))
```

**Step 4: Update template display logic**

The undescribed blurb (line 382) — add gallformers_code guard:

```heex
<div :if={@gall.undescribed && @gallformers_code} class="bg-amber-50 border border-amber-200 rounded-lg p-4">
```

The "formerly undescribed" blurb (lines 417-430) — replace:

```heex
<div
  :if={!@gall.undescribed && @gallformers_code}
  class="text-sm text-gray-600"
>
  Formerly tracked as undescribed —
  <a
    href={"https://www.inaturalist.org/observations?verifiable=any&place_id=any&field:Gallformers%20Code=#{URI.encode(@gallformers_code)}"}
    target="_blank"
    rel="noreferrer"
    class="text-gf-maroon hover:underline"
  >
    view iNat observations linked under Gallformers Code "{@gallformers_code}"
  </a>
</div>
```

**Step 5: Delete `compute_gallformers_code/3` function**

Remove lines 201-220.

**Step 6: Verify compilation and run tests**

```bash
mix compile --warnings-as-errors && mix test
```

**Step 7: Commit**

```
Update public gall page to use gallformers_code field

Display logic now reads from gall_traits.gallformers_code instead
of deriving from name/alias. Removes compute_gallformers_code/3.
```

---

## Task 9: Remove former_undescribed Alias Infrastructure

**Files:**
- Modify: `lib/gallformers/taxonomy/reclassification.ex`
- Modify: `lib/gallformers/species.ex`
- Modify: `lib/gallformers_web/live/admin/reclassify_live.ex`
- Modify: `lib/gallformers_web/components/form_components.ex`
- Modify: `test/gallformers/taxonomy_test.exs`
- Modify: `test/prod_data/invariants_test.exs`

This is the largest task. Work through it methodically.

**Step 1: Simplify `reclassification.ex`**

Replace `resolve_alias_opts/1` (lines 68-74) — all aliases are now `"scientific"`:

```elixir
defp resolve_alias_opts(_params) do
  {"scientific", false}
end
```

In `reclassify_species/2` (line 35): remove `former_undescribed_choice` from extracted params. Remove the `if rotate?` branch in `name_changed?` (line 58).

In `reassign_species_taxonomy/3` (line 88):
- Remove `rotate_former_undescribed` from opts (line 90)
- Remove `was_undescribed?` capture (line 94)
- Remove call to `maybe_rotate_former_undescribed` (line 100)
- Remove `was_undescribed?` parameter from `rename_species_for_reclassification` (line 106)

Simplify `resolve_reclassify_alias_type/2` (lines 150-152) — always `"scientific"`. Or remove entirely and pass `"scientific"` directly.

Delete `maybe_rotate_former_undescribed/2` (lines 182-186).

**Step 2: Remove functions from `species.ex`**

Delete:
- `has_former_undescribed_alias?/1` (lines 635-643)
- `rotate_former_undescribed_alias/1` (lines 653-671)

In `add_rename_alias/3` (lines 610-630), remove the `former_undescribed` guard.

**Step 3: Simplify `reclassify_live.ex`**

- Remove `:has_former_undescribed` from `init_component_state/1` (line 68)
- Remove `has_former_undescribed` computation from `open_modal/1` (lines 76-78)
- Remove `former_undescribed_choice` from `execute_reclassify/6` params (lines 322-333)
- Remove passing `has_former_undescribed` and `alias_choice` to the component (lines 133-134)

**Step 4: Simplify `form_components.ex` reclassify modal**

- Remove the `has_former_undescribed` attr (lines 1091-1093)
- Remove the `alias_choice` attr (lines 1095-1097)
- Remove the conditional former_undescribed radio group section (lines 1186-1228)
- Keep only the standard "Add scientific synonym alias" checkbox

**Step 5: Update tests**

In `test/gallformers/taxonomy_test.exs`:
- Tests asserting `former_undescribed` alias creation → change to expect `scientific`
- Delete tests for `has_former_undescribed_alias?` and `rotate_former_undescribed_alias`
- Delete tests for `former_undescribed_choice` parameter

In `test/prod_data/invariants_test.exs`:
- Remove "no species has more than one alias of type former_undescribed" test (lines 358-372)

**Step 6: Verify compilation and run full tests**

```bash
mix compile --warnings-as-errors && mix test
```

**Step 7: Commit**

```
Remove former_undescribed alias infrastructure

All alias creation during reclassification now uses "scientific" type.
Gallformers code is stored in gall_traits.gallformers_code instead.
Removes: has_former_undescribed_alias?, rotate_former_undescribed_alias,
former_undescribed_choice parameter, alias rotation logic.
```

---

## Task 10: Data Migration

**BLOCKED: Awaiting reviewer feedback on 3 action items (due Tuesday 2026-02-18).**

See [triage doc](Triaging%20the%20state%20of%20Gall%20species%20data.md) for full details.

**Pre-requisites before writing this migration:**
1. ID 1115 renamed (or decision to skip and fix manually after)
2. Duplicate gallformers codes resolved (IDs 4081/4082 and 2747/5443)
3. Fresh `make download-db` to get latest production data

**Files:**
- Create: migration via `mix ecto.gen.migration separate_undescribed_from_incomplete`

**Migration must use Elixir code (not raw SQL) for epithet extraction** — call `TaxonName.parse/1` to correctly handle both `"Genus epithet"` and `"Unknown (Family) epithet"` name formats.

**Operations:**

1. **Populate gallformers_code** from species name epithet for galls with 1+ dashes in epithet, excluding 23 legitimate described species:
   - 1 dash exclusions: 778, 1005, 1339, 1340, 1373, 1906, 1996, 2255, 2688, 3167, 3346, 3979, 3981, 3992, 4089, 4092, 4603, 4792, 5027, 5578, 5645
   - 2 dash exclusions: 633, 4614

2. **Populate gallformers_code from former_undescribed aliases** (none exist today; defensive)

3. **Fix undescribed flags:**
   - ID 2235 → set undescribed = true
   - All undescribed galls with real genus AND no dashes in epithet → set undescribed = false (except ID 1115)
   - All galls under Unknown genera → ensure undescribed = true

4. **Fix datacomplete:**
   - All galls without sources → set datacomplete = false
   - All undescribed galls → set datacomplete = false

5. **Clean up aliases:** Convert any `former_undescribed` aliases to `scientific` type

**Post-migration spot checks:**

```elixir
# No undescribed galls with real genera and no dashes (except 1115 if not yet fixed)
# No former_undescribed aliases
# No datacomplete galls without sources
# No datacomplete undescribed galls
# No duplicate gallformers_code values
# Count of galls with gallformers_code populated
```

**Commit:**

```
Migrate data: separate undescribed from incomplete

Populates gallformers_code from species name epithets. Fixes
mislabeled undescribed flags. Enforces datacomplete rules.
Converts former_undescribed aliases to scientific.
```

---

## Task 11: Update Prod Data Invariant Tests

**Files:**
- Modify: `test/prod_data/invariants_test.exs`

**Step 1: Add new invariants**

```elixir
test "no gall with datacomplete=true lacks sources" do
  bad =
    Repo.all(
      from(s in "species",
        where: s.taxoncode == "gall",
        where: s.datacomplete == true,
        where: s.id not in subquery(from ss in "species_source", select: ss.species_id),
        select: %{id: s.id, name: s.name}
      )
    )

  assert bad == [],
         "Found #{length(bad)} complete galls without sources: #{inspect(Enum.take(bad, 10))}"
end

test "no undescribed gall has datacomplete=true" do
  bad =
    Repo.all(
      from(s in "species",
        join: gt in "gall_traits", on: gt.species_id == s.id,
        where: s.taxoncode == "gall",
        where: gt.undescribed == true,
        where: s.datacomplete == true,
        select: %{id: s.id, name: s.name}
      )
    )

  assert bad == [],
         "Found #{length(bad)} undescribed complete galls: #{inspect(Enum.take(bad, 10))}"
end

test "no duplicate gallformers_code values" do
  bad =
    Repo.all(
      from(gt in "gall_traits",
        where: not is_nil(gt.gallformers_code) and gt.gallformers_code != "",
        group_by: gt.gallformers_code,
        having: count(gt.species_id) > 1,
        select: gt.gallformers_code
      )
    )

  assert bad == [],
         "Found #{length(bad)} duplicate gallformers codes: #{inspect(bad)}"
end
```

**Step 2: Remove the former_undescribed invariant** (already removed in Task 9)

**Step 3: Commit**

```
Add invariants: datacomplete requires sources, undescribed blocks complete, unique gallformers codes
```

---

## Task 12: Final Verification

**Step 1: Run full precommit**

```bash
mix precommit
```

**Step 2: Run full CI check**

```bash
make ci
```

**Step 3: Manual smoke test**

Start the dev server and verify:
- Admin gall form: datacomplete checkbox locked with reason when no sources
- Admin gall form: datacomplete checkbox locked with reason when undescribed
- Admin gall form: undescribed checkbox only locked for Unknown genera
- Admin gall form: gallformers_code field visible and editable
- Admin gall form: gallformers_code uniqueness validated
- Public gall page: undescribed gall with code shows blurb + iNat link
- Public gall page: described gall with code shows "formerly" blurb
- Public gall page: gall without code shows nothing special
- Undescribed creation flow: gallformers_code pre-populated

**Step 4: Report results to user**
