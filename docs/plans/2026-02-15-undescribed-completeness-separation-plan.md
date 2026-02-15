# Undescribed/Completeness Separation — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Separate taxonomic "undescribed" status from entry "incomplete" status, promote gallformers code to a real data field, and clean up the former_undescribed alias infrastructure.

**Architecture:** Remove the source-check branch from `compute_undescribed_lock/2`. Add a parallel `compute_datacomplete_lock/1` that gates datacomplete on sources. Add `gallformers_code` string field to `gall_traits` and read it directly instead of deriving from names/aliases. Remove all `former_undescribed` alias machinery.

**Tech Stack:** Elixir/Phoenix LiveView, Ecto with SQLite, TDD with ExUnit.

**Working on:** `main` branch directly (no worktree).

**Design doc:** `docs/plans/2026-02-15-undescribed-completeness-separation-design.md`

---

## Task 1: Run Diagnostic Queries

**GATE: User must review results before any code changes proceed.**

**Step 1: Run diagnostics in IEx**

```bash
iex -S mix
```

Run these queries one at a time and record results:

```elixir
import Ecto.Query
alias Gallformers.Repo

# 1. Undescribed galls with real genera (the mislabeled ones)
real_genus_undescribed = Repo.all(
  from gt in "gall_traits",
    join: st in "species_taxonomy", on: st.species_id == gt.species_id,
    join: t in "taxonomy", on: st.taxonomy_id == t.id,
    join: s in "species", on: s.id == gt.species_id,
    where: gt.undescribed == true,
    where: t.type == "genus",
    where: not like(t.name, "Unknown%"),
    select: %{species_id: gt.species_id, name: s.name, genus: t.name}
)
IO.puts("Undescribed galls with real genera: #{length(real_genus_undescribed)}")

# 2. Of those, how many have sources vs don't
with_sources = Enum.filter(real_genus_undescribed, fn %{species_id: sid} ->
  Repo.exists?(from ss in "species_source", where: ss.species_id == ^sid)
end)
IO.puts("  With sources: #{length(with_sources)}")
IO.puts("  Without sources: #{length(real_genus_undescribed) - length(with_sources)}")

# 3. Galls marked datacomplete but lacking sources
complete_no_sources = Repo.all(
  from s in "species",
    where: s.taxoncode == "gall",
    where: s.datacomplete == true,
    where: s.id not in subquery(from ss in "species_source", select: ss.species_id),
    select: %{id: s.id, name: s.name}
)
IO.puts("Data-complete galls without sources: #{length(complete_no_sources)}")

# 4. Current former_undescribed aliases
former_aliases = Repo.all(
  from a in "alias",
    join: als in "alias_species", on: als.alias_id == a.id,
    join: s in "species", on: s.id == als.species_id,
    where: a.type == "former_undescribed",
    select: %{alias_id: a.id, alias_name: a.name, species_id: s.id, species_name: s.name}
)
IO.puts("Former undescribed aliases: #{length(former_aliases)}")
Enum.each(former_aliases, fn a -> IO.puts("  #{a.species_name} <- #{a.alias_name}") end)
```

**Step 2: Present results to user for review**

Show all counts and the list of former_undescribed aliases. Wait for user approval before proceeding.

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
  end
end
```

**Step 3: Add field to schema**

Modify `lib/gallformers/galls/gall_traits.ex`:

- Add `:gallformers_code` to `@optional_fields` (line 14)
- Add `field :gallformers_code, :string` to schema (after line 28)
- Add `gallformers_code: String.t() | nil` to `@type t` (after line 19)

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
```

---

## Task 3: Modify Undescribed Lock — Remove Source Check

**Files:**
- Modify: `lib/gallformers/galls.ex:669-682`
- Modify: `test/gallformers/galls_test.exs:361-423`

**Step 1: Update the test — remove "locked when no sources" case, change expectation**

In `test/gallformers/galls_test.exs`, the test at line 379 ("locked when species has no sources") should be changed to expect `{false, nil}` — a gall with a real genus and no sources should now be **unlocked**:

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

**Step 5: Run full test suite to check for regressions**

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

  test "unlocked when species has sources" do
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

A gall's datacomplete flag is locked to `false` when the species has no
sources linked. Returns `{locked?, reason}` where reason is a string
explaining the lock, or nil if unlocked.
"""
@spec compute_datacomplete_lock(integer() | nil) :: {boolean(), String.t() | nil}
def compute_datacomplete_lock(nil), do: {false, nil}

def compute_datacomplete_lock(species_id) do
  if Gallformers.Sources.has_sources?(species_id) do
    {false, nil}
  else
    {true, "A source is required to mark a gall as data complete."}
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
Add compute_datacomplete_lock to gate completeness on sources
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

There are 4 call sites in the file. After each `apply_undescribed_lock` call, pipe into `apply_datacomplete_lock`:

- Line 191: `|> apply_undescribed_lock(taxonomy)` — add `|> apply_datacomplete_lock()`
- Line 228: `|> apply_undescribed_lock(taxonomy)` — add `|> apply_datacomplete_lock()`
- Line 300: `|> apply_undescribed_lock(taxonomy, species_id)` — add `|> apply_datacomplete_lock(species_id)`
- Line 630: `|> apply_undescribed_lock(taxonomy, species_id)` — add `|> apply_datacomplete_lock(species_id)`

**Step 4: Update the template — lock the datacomplete checkbox**

Replace the datacomplete checkbox section (around lines 1132-1136) from:

```heex
<.input
  type="checkbox"
  field={@form[:datacomplete]}
  label="All sources containing unique information relevant to this gall have been added and are reflected in its associated data. However, filter criteria may not be comprehensive in every field."
/>
```

To a manual checkbox with lock behavior (matching the undescribed pattern):

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

In `save_gall/3` for `:new` (around line 708), the `species_attrs` params map already includes `datacomplete` from the form. But when the checkbox is disabled, browsers don't submit it — so it defaults to false. No special handling needed for create.

For `:edit` (around line 736), same principle applies. But to be safe, add defensive enforcement in `update_gall_with_associations` or at the form level: if `datacomplete_locked` is true, force the species_attrs datacomplete to false before passing to the context. Add this in `save_gall/3` for `:edit`:

After `|> Map.put("name", socket.assigns.gall.name)` in the save handler (line 412), add:

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
the gall has no sources, mirroring the undescribed lock pattern.
```

---

## Task 6: Add Gallformers Code to Gall Admin Form

**Files:**
- Modify: `lib/gallformers_web/live/admin/gall_live/form.ex`
- Modify: `lib/gallformers/galls.ex` (update `create_gall_with_associations`, `update_gall_with_associations`)

**Step 1: Add gallformers_code to save params**

In `save_gall/3` for `:new` (around line 709), add `gallformers_code` to `create_params`:

```elixir
gallformers_code: socket.assigns[:gallformers_code]
```

In `save_gall/3` for `:edit` (around line 740), add `gallformers_code` to `update_params`:

```elixir
gallformers_code: socket.assigns[:gallformers_code]
```

**Step 2: Update `update_gall_properties` calls in `create_gall_with_associations` and `update_gall_with_associations`**

In `lib/gallformers/galls.ex`, the `update_gall_properties` call in `create_gall_with_associations` (line 841) becomes:

```elixir
update_gall_properties(species.id, %{
  detachable: params.detachable,
  undescribed: params.undescribed,
  gallformers_code: params[:gallformers_code]
})
```

Same for `update_gall_with_associations` (line 890):

```elixir
update_gall_properties(species.id, %{
  detachable: params.detachable,
  undescribed: params.undescribed,
  gallformers_code: params[:gallformers_code]
})
```

**Step 3: Add assign and form field**

In the form's default assigns setup, add:

```elixir
|> assign(:gallformers_code, nil)
```

In `load_gall_for_edit`, after loading the gall, fetch the gallformers_code from gall_traits:

```elixir
gall_traits = Repo.get(Gallformers.Galls.GallTraits, species_id)
```

Then assign it:

```elixir
|> assign(:gallformers_code, gall_traits && gall_traits.gallformers_code)
```

Add a handle_event for the field:

```elixir
def handle_event("update_gallformers_code", %{"value" => value}, socket) do
  {:noreply, socket |> assign(:gallformers_code, value) |> mark_dirty()}
end
```

**Step 4: Add template input**

In the template, near the undescribed checkbox section (around line 1157), add:

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

In `undescribed.ex`, the `continue` event handler (line 373) navigates with query params. Add the gallformers code (derived from the epithet of the generated name):

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

**Step 2: Read gallformers_code in the form's init_from_undescribed_flow**

In `form.ex`, the function that handles the undescribed flow params (around line 195, `init_undescribed_gall_with_taxonomy`) needs to read and assign the gallformers_code from the query params. Find where it reads `species_name` and `undescribed` from params, and add:

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

In `gall_live.ex`, around line 103-104, replace:

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

Change the `gallformers_code` assign to use the field value directly (it's already named `gallformers_code`).

**Step 3: Remove the former_undescribed filter from scientific_aliases**

Lines 100-101 currently filter out `former_undescribed`:

```elixir
scientific_aliases =
  Enum.filter(aliases, &(&1.type not in ["common", "former_undescribed"]))
```

Change to:

```elixir
scientific_aliases =
  Enum.filter(aliases, &(&1.type != "common"))
```

(Once the migration converts former_undescribed aliases to scientific, this handles them correctly.)

**Step 4: Update template display logic**

The undescribed blurb (line 382) currently checks `@gall.undescribed`. Change to check for both undescribed AND gallformers_code:

```heex
<div :if={@gall.undescribed && @gallformers_code} class="bg-amber-50 border border-amber-200 rounded-lg p-4">
```

The "formerly undescribed" blurb (line 417-430) currently checks `!@gall.undescribed && @former_undescribed_name`. Change to:

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

Note: The old template showed the former_undescribed_name with `.taxon_name`. Since we no longer store the former name (just the code), the display simplifies.

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

Replace `resolve_alias_opts/1` (lines 68-74). The function currently routes between `"scientific"` and `"former_undescribed"`. All aliases should now be `"scientific"`:

```elixir
defp resolve_alias_opts(_params) do
  {"scientific", false}
end
```

Remove `maybe_rotate_former_undescribed/2` (lines 182-186) — replace calls with no-ops.

In `reassign_species_taxonomy/3` (line 88):
- Remove `rotate_former_undescribed` from opts (line 90)
- Remove `was_undescribed?` capture (line 94) — it's only used for alias type resolution
- Remove call to `maybe_rotate_former_undescribed` (line 100)
- Remove `was_undescribed?` parameter from `rename_species_for_reclassification` (line 106)

Simplify `resolve_reclassify_alias_type/2` (lines 150-152) to always return `"scientific"`:

```elixir
defp resolve_reclassify_alias_type(_explicit, _was_undescribed), do: "scientific"
```

Or better: remove it entirely and just pass `"scientific"` directly in `rename_species_for_reclassification`.

In `reclassify_species/2` (line 35):
- Remove `former_undescribed_choice` from the extracted params
- The `rotate?` variable from `resolve_alias_opts` is now always `false`, so the `if rotate?` branch in `name_changed?` (line 58) is dead — remove it.

**Step 2: Remove functions from `species.ex`**

Delete these functions:
- `has_former_undescribed_alias?/1` (lines 635-643)
- `rotate_former_undescribed_alias/1` (lines 653-671)

In `add_rename_alias/3` (lines 610-630), remove the `former_undescribed` guard:

```elixir
def add_rename_alias(species_id, old_name, type \\ "scientific") do
  alias_changeset =
    %Alias{}
    |> Alias.changeset(%{name: old_name, type: type, description: "Previous name"})
  # ... rest of the create logic (without the former_undescribed check)
end
```

**Step 3: Simplify `reclassify_live.ex`**

In `init_component_state/1` (line 68): remove `:has_former_undescribed` assign.
In `open_modal/1` (lines 76-78): remove the `has_former_undescribed` computation and assign.
In `execute_reclassify/6` (lines 322-333): remove `former_undescribed_choice` from params.
Remove passing `has_former_undescribed` and `alias_choice` to the component (line 133-134).

**Step 4: Simplify `form_components.ex` reclassify modal**

Remove the `has_former_undescribed` attr (lines 1091-1093).
Remove the `alias_choice` attr (lines 1095-1097).
Remove the conditional former_undescribed radio group section (lines 1186-1228). Keep only the standard "Add scientific synonym alias" checkbox.

**Step 5: Update tests**

In `test/gallformers/taxonomy_test.exs`:
- Tests that assert `former_undescribed` alias creation should now assert `scientific` alias creation instead
- Tests for `has_former_undescribed_alias?` and `rotate_former_undescribed_alias` should be deleted
- Tests for `former_undescribed_choice` parameter should be deleted or simplified

In `test/prod_data/invariants_test.exs`:
- Remove the "no species has more than one alias of type former_undescribed" test (lines 358-372)

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

**GATE: Only proceed after Task 1 diagnostics are reviewed and approved by user.**

**Files:**
- Create: migration via `mix ecto.gen.migration separate_undescribed_from_incomplete`

**Step 1: Generate migration**

```bash
mix ecto.gen.migration separate_undescribed_from_incomplete
```

**Step 2: Write the migration**

```elixir
defmodule Gallformers.Repo.Migrations.SeparateUndescribedFromIncomplete do
  use Gallformers.Migration

  def up do
    # 1. Populate gallformers_code from former_undescribed aliases
    # (these have the original undescribed name — extract the epithet)
    execute("""
    UPDATE gall_traits
    SET gallformers_code = (
      SELECT REPLACE(TRIM(SUBSTR(a.name, INSTR(a.name, ' ') + 1)), ' ', '-')
      FROM alias a
      JOIN alias_species als ON als.alias_id = a.id
      WHERE als.species_id = gall_traits.species_id
        AND a.type = 'former_undescribed'
      LIMIT 1
    )
    WHERE species_id IN (
      SELECT als.species_id
      FROM alias a
      JOIN alias_species als ON als.alias_id = a.id
      WHERE a.type = 'former_undescribed'
    )
    """)

    # 2. Populate gallformers_code for currently-undescribed galls that don't have one yet
    # (extract epithet from current species name)
    execute("""
    UPDATE gall_traits
    SET gallformers_code = (
      SELECT REPLACE(TRIM(SUBSTR(s.name, INSTR(s.name, ' ') + 1)), ' ', '-')
      FROM species s
      WHERE s.id = gall_traits.species_id
    )
    WHERE undescribed = 1
      AND (gallformers_code IS NULL OR gallformers_code = '')
    """)

    # 3. Fix undescribed flags: un-undescribe galls with real genera
    execute("""
    UPDATE gall_traits SET undescribed = 0
    WHERE undescribed = 1
      AND species_id IN (
        SELECT st.species_id FROM species_taxonomy st
        JOIN taxonomy t ON st.taxonomy_id = t.id
        WHERE t.type = 'genus' AND t.name NOT LIKE 'Unknown%'
      )
    """)

    # 4. Fix datacomplete: ensure no sourceless gall claims completeness
    execute("""
    UPDATE species SET datacomplete = 0
    WHERE datacomplete = 1
      AND taxoncode = 'gall'
      AND id NOT IN (SELECT species_id FROM species_source)
    """)

    # 5. Convert former_undescribed aliases to scientific
    execute("""
    UPDATE alias SET type = 'scientific'
    WHERE type = 'former_undescribed'
    """)
  end

  def down do
    # Not reversible — data was corrected
    :ok
  end
end
```

**Important note on epithet extraction:** The SQL `SUBSTR(name, INSTR(name, ' ') + 1)` extracts everything after the first space. For names like `"Unknown (Cynipidae) q-lobata-leaf-blister"`, this gives `"(Cynipidae) q-lobata-leaf-blister"` which is wrong. We need a smarter approach for Unknown genus names.

A safer approach: use Elixir code in the migration to call `TaxonName.parse/1`:

```elixir
def up do
  # 1. Populate gallformers_code from former_undescribed aliases
  former_aliases = repo().all(
    from a in "alias",
      join: als in "alias_species", on: als.alias_id == a.id,
      where: a.type == "former_undescribed",
      select: {als.species_id, a.name}
  )

  for {species_id, alias_name} <- former_aliases do
    epithet = Gallformers.Taxonomy.TaxonName.parse(alias_name).epithet
    if epithet do
      repo().query!("UPDATE gall_traits SET gallformers_code = ?1 WHERE species_id = ?2",
        [epithet, species_id])
    end
  end

  # 2. Populate for currently-undescribed galls without a code yet
  undescribed_without_code = repo().all(
    from gt in "gall_traits",
      join: s in "species", on: s.id == gt.species_id,
      where: gt.undescribed == true,
      where: is_nil(gt.gallformers_code) or gt.gallformers_code == "",
      select: {gt.species_id, s.name}
  )

  for {species_id, name} <- undescribed_without_code do
    epithet = Gallformers.Taxonomy.TaxonName.parse(name).epithet
    if epithet do
      repo().query!("UPDATE gall_traits SET gallformers_code = ?1 WHERE species_id = ?2",
        [epithet, species_id])
    end
  end

  # 3-5: SQL operations (same as above)
  # ...
end
```

**Step 3: Run migration**

```bash
mix ecto.migrate
```

**Step 4: Spot-check results**

```bash
iex -S mix
```

```elixir
import Ecto.Query
alias Gallformers.Repo

# Verify no undescribed galls with real genera remain
bad = Repo.all(
  from gt in "gall_traits",
    join: st in "species_taxonomy", on: st.species_id == gt.species_id,
    join: t in "taxonomy", on: st.taxonomy_id == t.id,
    where: gt.undescribed == true,
    where: t.type == "genus",
    where: not like(t.name, "Unknown%"),
    select: gt.species_id
)
IO.puts("Undescribed with real genera (should be 0): #{length(bad)}")

# Verify no former_undescribed aliases remain
former = Repo.one(from a in "alias", where: a.type == "former_undescribed", select: count(a.id))
IO.puts("Former undescribed aliases (should be 0): #{former}")

# Verify gallformers_code populated
codes = Repo.one(from gt in "gall_traits", where: not is_nil(gt.gallformers_code) and gt.gallformers_code != "", select: count(gt.species_id))
IO.puts("Galls with gallformers_code: #{codes}")
```

**Step 5: Commit**

```
Migrate data: separate undescribed from incomplete

Populates gallformers_code from former_undescribed aliases and
undescribed species names. Fixes mislabeled undescribed flags.
Converts former_undescribed aliases to scientific.
```

---

## Task 11: Update Prod Data Invariant Tests

**Files:**
- Modify: `test/prod_data/invariants_test.exs`

**Step 1: Add new invariant — no datacomplete gall without sources**

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
```

**Step 2: The former_undescribed invariant test (line 358) was already removed in Task 9.**

**Step 3: Verify prod data tests pass (if prod data available)**

```bash
make test-prod-data
```

**Step 4: Commit**

```
Add invariant: datacomplete galls must have sources
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
- Admin gall form: undescribed checkbox only locked for Unknown genera
- Admin gall form: gallformers_code field visible and editable
- Public gall page: undescribed gall with code shows blurb + iNat link
- Public gall page: described gall with code shows "formerly" blurb
- Public gall page: gall without code shows nothing special
- Undescribed creation flow: gallformers_code pre-populated

**Step 4: Report results to user**
