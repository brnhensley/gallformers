---
status: planned
created: 2026-03-23
updated: 2026-03-24
epic: platform
relates: [b016]
blocks: [881c]
---

# Architectural fitness testing — Boundary + custom Credo checks

## Problem

LLM agents produce code that compiles and passes tests but violates architectural intent. Traditional testing catches logical bugs; it doesn't catch structural violations. The only reliable defense is deterministic enforcement that fails the build.

This is not developer drift (slow erosion over months). LLM failure modes are fast and non-deterministic:
- Boundary blindness (C3): agents call internal modules because they're "closer" in vector space
- Test-passing logic errors (C1): agent-written tests share the same blind spots as agent-written code
- Architectural decision reversal (C14): agents ignore documented constraints when a quicker path exists
- Code duplication explosion (C8): agents duplicate rather than discover existing abstractions

(C-codes reference Na'im Ru's "Taxonomy of LLM Failure Modes", Jan 2026)

## Design: Three Layers

### Layer 1: Boundary Library (module dependency enforcement)

Declare allowed dependencies at compile time. `mix compile` emits warnings (which `--warnings-as-errors` in precommit turns into build failures).

**Rules to encode:**

| Rule | Rationale |
|------|-----------|
| Taxonomy → no deps | Foundation for 881c; taxonomy owns the tree |
| Species → Taxonomy only | Thin shared module, not an orchestrator |
| Galls ↛ Plants, Plants ↛ Galls | Peer contexts, no cross-calling |
| Web → Contexts only, never Repo | Arch principle 1 & 5: LiveViews are routers, contexts own transactions |
| Web → context public APIs only | No calling Taxonomy.Tree or Galls.Identification directly |

**Adoption strategy:** Declare boundaries for all ~33 contexts. Use `dirty_xrefs: [Module1, ...]` to whitelist existing violations. Each dirty_xref entry is a visible TODO. The checker warns if you clean one up and forget to remove it. `check: [out: false]` available for boundaries too messy to itemize initially.

**Cycle detection** comes free with Boundary — mutual deps are flagged automatically.

### Layer 2: Custom Credo Checks (pattern-level constraints)

AST-based checks in `lib/credo/checks/architecture/`. Run as part of `mix credo --strict` (already in precommit). ~30-60 lines each.

**Layer enforcement (arch principles 1 & 5):**
1. No `Repo` calls in `GallformersWeb.*` modules
2. No `Repo.transaction` outside `lib/gallformers/` contexts
3. No `import Ecto.Query` in LiveView modules

**Domain ownership (881c-critical):**
4. `:name` field on Species schema only cast/changed by Taxonomy modules

**Anti-mock (testing philosophy + LLM defense):**
5. No `Mox`, `:meck`, mock library imports anywhere (allowed stubs use behaviours, zero false positives)

**Test quality (LLM defense — no traditional precedent):**
6. LiveView tests that call form submit/push_patch must also contain a Repo call (catches flash-only assertions)
7. No hardcoded integer IDs in `Repo.get/get!/one/one!` calls in test files (catches seed data coupling)
8. Flag bare `assert variable` with no comparison operator in test files (catches truthiness-only assertions)
9. Test files that perform DB reads must also perform DB writes (catches tests that don't own their data)

### Layer 3: Incremental Execution Infrastructure

Adding 12+ checks to a sequential precommit makes feedback painful. Slow tools get bypassed — defeating the purpose.

**Tier 1 — Precommit (fast, <10s): Changed files only**
- Credo targets changed files: `mix credo --strict path/to/changed.ex`
- Boundary is incremental (runs as compiler, only recompiles changed modules + dependents)
- `mix compile --warnings-as-errors` already incremental
- Map changed source files → corresponding test files, run only those

**Tier 2 — Background (post-commit): Full suite**
- Full `mix credo --strict`, `mix test`, Boundary check
- Desktop notification on failure (macOS osascript/terminal-notifier)
- Pattern: `make check-full` in background

**Tier 3 — CI (authoritative): Everything**
- Existing `make ci` pipeline, no shortcuts
- This is the merge gate

Changed-file detection via `git diff --name-only`. Same pattern as existing `make e2e-changed`.

## What This Defends Against

| LLM Failure Mode | Which checks catch it |
|---|---|
| Bypass context, call Repo from LiveView | Credo #1, #2, #3 + Boundary |
| Call internal modules directly | Boundary exports |
| Violate field ownership | Credo #4 |
| Mock to make tests pass | Credo #5 |
| Assert on flash, not DB state | Credo #6 |
| Depend on seed data | Credo #7, #9 |
| Write truthiness-only assertions | Credo #8 |
| Introduce circular context deps | Boundary cycle detection |
| Reverse architectural decisions | Boundary + Credo layer checks |

## Out of Scope (Future Work)

- **Code duplication detection** — high value but noisy as automated check. Existing CLAUDE.md "Search Before You Write" rule is the current mitigation.
- **Property-based testing enforcement** — addresses C1 root cause but heavier tooling.
- **Mutation testing** — verifies test quality mechanically but slow.
- **Test file structural convention checks** — low value, enforced by Phoenix generators.

## Relationship to Other Matters

- **Blocks 881c** — fitness tests encode Taxonomy→Species dependency direction and name ownership before 881c establishes them
- **Relates to b016** (test suite alignment) — test quality Credo checks (6-9) are mechanical enforcement of testing philosophy principles


## Implementation Plan

**Goal:** Add deterministic architectural enforcement that fails the build when structural constraints are violated — defending against LLM agents and future developer drift.

**Architecture:** Boundary library for module-level dependency enforcement (compile-time). Custom Credo checks for pattern-level constraints (lint-time). Incremental execution infrastructure so checks stay fast enough to actually run.

**Tech Stack:** Boundary ~> 0.10, Credo custom checks (AST-based), Make/mix aliases.

### Task 1: Add Boundary library and declare all boundaries

**Files:**
- Modify: `mix.exs` (add dep, add compiler)
- Modify: `lib/gallformers/taxonomy.ex` (add `use Boundary`)
- Modify: `lib/gallformers/species.ex` (add `use Boundary`)
- Modify: `lib/gallformers/galls.ex` (add `use Boundary`)
- Modify: `lib/gallformers/plants.ex` (add `use Boundary`)
- Modify: all ~33 context modules (add `use Boundary` declarations)
- Modify: `lib/gallformers_web.ex` (add `use Boundary` for web layer)
- Test: `mix compile --warnings-as-errors` passes (Boundary integrates as compiler)

**Behavior:**
Add `{:boundary, "~> 0.10", runtime: false}` to deps. Add `:boundary` to compilers list in mix.exs project config. Then declare boundaries on every top-level context module.

Key boundary rules:
- `Gallformers.Taxonomy` — `deps: []` (no deps on other contexts, foundation)
- `Gallformers.Species` — `deps: [Gallformers.Taxonomy]` (one-way)
- `Gallformers.Galls` — `deps: [Gallformers.Species, Gallformers.Taxonomy, Gallformers.FilterFields, ...]`
- `Gallformers.Plants` — `deps: [Gallformers.Species, Gallformers.Taxonomy, ...]` (NOT Galls)
- `GallformersWeb` — `deps: [all contexts]` but NOT `Gallformers.Repo` directly

Use `dirty_xrefs: [Module, ...]` to whitelist every existing violation. Run `mix compile` to discover the full list. Each dirty_xref is a visible TODO — Boundary warns when you clean one up and forget to remove it.

**Testing:**
- Project compiles with `--warnings-as-errors` after all boundaries declared
- Adding a new cross-boundary call (e.g., Plants calling Galls) fails compilation
- Verify dirty_xrefs list is complete (no warnings)

**Notes:**
This is the longest task. Discovering and whitelisting all existing violations takes patience. Don't try to fix violations in this task — just whitelist them. The goal is to get the fence up, not move the cattle.

Boundary integrates as an Elixir compiler — it runs during `mix compile`, not as a separate step. No need to add it to precommit explicitly; `mix compile --warnings-as-errors` (already in precommit) catches Boundary violations.

### Task 2: Credo checks 1-3 (layer enforcement)

**Files:**
- Create: `lib/credo/checks/architecture/no_repo_in_web.ex`
- Create: `lib/credo/checks/architecture/no_transaction_outside_context.ex`
- Create: `lib/credo/checks/architecture/no_ecto_query_in_liveview.ex`
- Modify: `.credo.exs` (add custom checks directory)
- Test: `test/credo/checks/architecture/no_repo_in_web_test.exs`
- Test: `test/credo/checks/architecture/no_transaction_outside_context_test.exs`
- Test: `test/credo/checks/architecture/no_ecto_query_in_liveview_test.exs`

**Behavior:**
Three AST-based Credo checks enforcing architectural principles 1 & 5:

Check 1 — `NoRepoInWeb`: Flag any call to `Repo.*` or `alias Gallformers.Repo` in modules under `GallformersWeb.*`. AST pattern: look for `{{:., _, [{:__aliases__, _, [:Repo | _]}, _]}, _, _}` calls and `{:alias, _, [{:__aliases__, _, [..., :Repo]}]}` declarations. Exclude test files.

Check 2 — `NoTransactionOutsideContext`: Flag `Repo.transaction` calls in any module NOT under `Gallformers.*` (excluding `GallformersWeb.*`). Also flag it in LiveView/LiveComponent modules.

Check 3 — `NoEctoQueryInLiveView`: Flag `import Ecto.Query` in any module under `GallformersWeb.*.Live.*` or any module that `use GallformersWeb, :live_view` or `:live_component`.

**Testing:**
Credo checks are tested by creating source code strings and asserting issues/no-issues:

```elixir
test "flags Repo.all in a web module" do
  source = ~S'''
  defmodule GallformersWeb.SomeLive do
    alias Gallformers.Repo
    def handle_event(_, _, socket) do
      Repo.all(query)
    end
  end
  '''
  assert_issue(source)
end

test "allows Repo.all in a context module" do
  source = ~S'''
  defmodule Gallformers.Galls do
    alias Gallformers.Repo
    def list_galls, do: Repo.all(query)
  end
  '''
  refute_issues(source)
end
```

**Notes:**
Add `requires: ["lib/credo/checks/"]` or equivalent to `.credo.exs` so custom checks are discovered. Credo custom check API: `use Credo.Check`, implement `run/2` which receives the source file AST. Use `Credo.Check.refute_issues` and `assert_issue` in tests.

### Task 3: Credo check 4 (species.name ownership)

**Files:**
- Create: `lib/credo/checks/architecture/species_name_ownership.ex`
- Test: `test/credo/checks/architecture/species_name_ownership_test.exs`

**Behavior:**
Flag any changeset operation that casts or changes the `:name` field on the Species schema, unless the module is under `Gallformers.Taxonomy.*`.

AST patterns to detect:
- `cast(changeset, params, [..., :name, ...])` — :name in the fields list of a cast call
- `change(species, %{name: ...})` or `change(species, name: ...)` — :name in a change call
- `Ecto.Changeset.force_change(changeset, :name, ...)` — force_change on :name

Only flag when the enclosing module is NOT `Gallformers.Taxonomy.*`. This is the 881c-critical check.

**Testing:**
- Species module casting `:name` → flagged
- Taxonomy module casting `:name` → not flagged
- Species module casting `:taxoncode` → not flagged
- Raw `Repo.update_all` with `set: [name: ...]` in Species → this is harder to catch via AST; document as a known limitation and rely on Boundary for module-level protection

**Notes:**
This check has the highest false-negative risk because `Repo.update_all` bypasses changesets entirely. The defense-in-depth is: Boundary prevents Species from calling Taxonomy internals, and this check prevents Species from using changesets to write :name. Together they cover the main paths. A `Repo.update_all` on the species table from a Species module would need to be caught by code review or a separate grep-based check.

### Task 4: Credo check 5 (anti-mock)

**Files:**
- Create: `lib/credo/checks/architecture/no_mocking_libraries.ex`
- Test: `test/credo/checks/architecture/no_mocking_libraries_test.exs`

**Behavior:**
Flag any import, alias, or use of `Mox`, `:meck`, `Mock`, `ExMachina` (if it's used for mocking, not factories), or other mock libraries. AST pattern: look for `use Mox`, `import Mox`, `:meck.new`, etc.

The project uses behaviours for abstraction boundaries (e.g., `Gallformers.S3` wraps `ExAws`). Mocking is never appropriate — stubs via behaviours or test fixtures are the pattern.

**Testing:**
- `use Mox` → flagged
- `import Mox` → flagged
- `:meck.new(Module)` → flagged
- `use Gallformers.DataCase` → not flagged

### Task 5: Credo checks 6-9 (test quality — LLM defense)

**Files:**
- Create: `lib/credo/checks/test_quality/flash_only_assertions.ex`
- Create: `lib/credo/checks/test_quality/no_hardcoded_ids.ex`
- Create: `lib/credo/checks/test_quality/no_bare_truthiness_assert.ex`
- Create: `lib/credo/checks/test_quality/tests_own_their_data.ex`
- Test: `test/credo/checks/test_quality/flash_only_assertions_test.exs`
- Test: `test/credo/checks/test_quality/no_hardcoded_ids_test.exs`
- Test: `test/credo/checks/test_quality/no_bare_truthiness_assert_test.exs`
- Test: `test/credo/checks/test_quality/tests_own_their_data_test.exs`

**Behavior:**

Check 6 — `FlashOnlyAssertions`: In test files, if a test block calls `render_submit`, `render_click` with a form event, or `push_patch`, it must also contain `Repo.get`, `Repo.one`, `Repo.all`, or a context query function call. Catches tests that only assert on flash messages without verifying DB state.

Check 7 — `NoHardcodedIds`: In test files, flag `Repo.get(Schema, 1)`, `Repo.get!(Schema, 42)`, `Repo.one(from s in Schema, where: s.id == 7)` — any literal integer passed as an ID to a Repo lookup. Tests should use IDs from fixtures they created.

Check 8 — `NoBareTruthinessAssert`: In test files, flag `assert variable` where `variable` is a bare variable with no comparison (`==`, `=~`, `in`, `!=`). Allow `assert true`, `assert match`, `assert_raise`, `assert_receive`, `assert {:ok, _} = ...` (pattern match). Flag `assert result` or `assert socket.assigns.something`.

Check 9 — `TestsOwnTheirData`: In test files, if a test block calls `Repo.get`/`Repo.one`/`Repo.all` (reads), it must also call `Repo.insert`/`insert!` or a fixture/factory function. Catches tests relying on seed data.

**Testing:**
Each check gets positive (flagged) and negative (allowed) test cases as described.

**Notes:**
These checks may have false positives in edge cases. Start with `priority: :low` so they appear as suggestions in strict mode rather than hard errors. Promote to higher priority after tuning. Checks 6 and 9 are the most likely to need refinement — the AST analysis for "does this test block contain X" requires walking the test's do-block, not just the file.

### Task 6: Incremental execution infrastructure

**Files:**
- Modify: `mix.exs` (update precommit alias)
- Modify: `Makefile` (add `check-full` and `check-bg` targets)
- Modify: `.credo.exs` (ensure custom checks directory is configured)

**Behavior:**

**Tier 1 — Precommit (fast):**
Update precommit alias to target changed files for Credo:

```elixir
precommit: [
  "format_check",
  "compile --warnings-as-errors",   # includes Boundary (incremental)
  "credo.changed --strict",          # new: only changed files
  "deps.unlock --unused",
  "test",
  "test.check_exclusions"
]
```

Create a `mix credo.changed` task that:
1. Runs `git diff --name-only HEAD` to get changed files
2. Filters to `.ex` and `.exs` files
3. Runs `mix credo --strict` with only those files as arguments

If no files changed, skip. If `git diff` fails (fresh repo), fall back to full credo.

**Tier 2 — Background:**
Add `make check-full` that runs full credo + compile + test. Add `make check-bg` that runs `check-full` in background and sends a macOS notification on failure:

```makefile
check-full:
	mix compile --warnings-as-errors && mix credo --strict && mix test

check-bg:
	@$(MAKE) check-full 2>&1 || osascript -e 'display notification "Check failed" with title "Gallformers"' &
```

**Testing:**
- `mix precommit` completes in reasonable time (<30s for typical changes)
- `make check-bg` runs in background and notifies on failure
- `mix credo.changed` with no changes exits cleanly

### Task 7: Documentation and verification

**Files:**
- Modify: `CLAUDE.md` (add Boundary and Credo check documentation)
- Modify: `CODING_STANDARDS.md` (add architectural fitness section)

**Behavior:**
Document:
- How to add a new Boundary declaration
- How to write a new custom Credo check
- The dirty_xrefs pattern and how to clean them up
- The three-tier execution model
- What each check catches and why it exists

Run full verification:
- `mix precommit` passes
- `make ci` passes
- All custom Credo check tests pass
- Boundary declarations compile without warnings (only dirty_xrefs expected)

**Testing:**
- `mix precommit` passes
- All new test files pass
- No new warnings from `mix compile --warnings-as-errors`
