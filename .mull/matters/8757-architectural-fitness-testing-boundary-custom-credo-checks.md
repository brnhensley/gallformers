---
status: refined
created: 2026-03-23
updated: 2026-03-23
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
