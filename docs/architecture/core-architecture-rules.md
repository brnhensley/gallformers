## Architectural Principles

These principles govern where code belongs. When in doubt, apply these before writing anything.

### 1. LiveViews are routers, not orchestrators

A LiveView's job is to translate user events into context calls and context results into assigns.

### 2. If state has its own lifecycle, it's a LiveComponent

The test: if you can open it, interact with it, and close it without the parent caring about intermediate states, extract it. A modal with its own assigns, events, and open/close/search/submit flow is a complete lifecycle independent of the parent form — that's a component, not "part of the form."

### 3. Duplication across LiveViews means a missing abstraction below them

Two LiveViews doing the same thing is never a "copy it and tweak" situation. The shared logic belongs in one of three places:
- **LiveComponent** — owns UI + state
- **Handler module** — operates on socket, no UI
- **Context function** — no socket at all, pure domain logic

Pick based on whether it needs to render, needs the socket, or is pure domain logic.

### 4. One function sets defaults, callers override

When you have 3+ functions that each set 25 assigns with slight variations, you don't have 3 functions — you have 1 function with 3 sets of overrides. Build a single `build_default_assigns` and let each path override only what's different. Forgotten assigns become impossible.

### 5. Contexts own transactions, not callers

`Repo.transaction` in a LiveView means the UI layer decides what's atomic. That's a domain decision. Wrap the "create X with all its associations" into a single context function that accepts a params map. The LiveView's only job is assembling that map from assigns and handling the `{:ok, _}` / `{:error, _}` result.

### 6. Domain concepts deserve types, not strings

A species name isn't a string — it has internal structure (genus, epithet, qualifier, unknown flag). When a domain concept has structure, model it as a struct/type. Every time someone writes `String.split(name, " ", parts: 2)` they're re-discovering that structure ad-hoc.

Test: if you're parsing the same string format in more than one place, it's an unmodeled type.

### 7. Formatting rules belong to the domain, not the template

"Genus and species italic, family not" is a biological convention — it's domain knowledge. It shouldn't be rediscovered by each template author deciding whether to use `<em>` or `italic`. Domain rules get a single authoritative function; templates call it.

Test: if a new developer would need to know something to format correctly, that knowledge needs to be in code, not convention.

### 8. One concept, one component

If the same visual pattern appears in 20+ files, it should be a component — even if each instance is "just one line." The component isn't about saving keystrokes, it's about making the rule changeable in one place and making violations grep-able. A stray `<em>` is invisible; a missing `<.taxon_name>` is findable.

Test: could a styling rule change (e.g., "sections should no longer be italic") be made in one file? If not, you have a missing component.

### 9. Semantic markup over visual classes

`<em class="taxon-name">` tells you what it is. `<span class="italic">` tells you how it looks today. When someone reads the template, the semantic version communicates intent. When someone greps the codebase, the semantic version finds all taxonomic names. The visual version is invisible among hundreds of other italicized things.

## Architectural Enforcement (Boundary + Credo)

The codebase uses **Boundary** (compile-time) and **custom Credo checks** (lint-time) to enforce architectural rules. These are not optional — they fail the build.

### Boundary (module dependency enforcement)

Every context module declares `use Boundary` with its allowed dependencies. Adding a cross-boundary call that isn't declared will fail `mix compile --warnings-as-errors`.

- **To add a new dependency**: add the target boundary to the `deps:` list in the source module's `use Boundary` declaration
- **`dirty_xrefs`**: existing violations whitelisted as TODOs. Boundary warns if you clean one up and forget to remove it from the list
- **Cycles**: three known dependency cycles documented in matter 82f8. They show as warnings, not errors.

### Custom Credo Checks

Located in `lib/credo/checks/`. Registered in `.credo.exs`.

**Architecture checks** (`lib/credo/checks/architecture/`):
- `NoRepoInWeb` — no `Repo` calls in `GallformersWeb.*` modules
- `NoTransactionOutsideContext` — no `Repo.transaction` in web modules
- `NoEctoQueryInLiveView` — no `import Ecto.Query` in web modules
- `SpeciesNameOwnership` — only `Gallformers.Taxonomy.*` modules may cast/change `:name` on Species
- `NoMockingLibraries` — no `Mox`, `Mock`, `:meck` usage

**Test quality checks** (`lib/credo/checks/test_quality/`):
- `FlashOnlyAssertions` — tests with form submissions must verify DB state, not just flash
- `NoHardcodedIds` — no literal integer IDs in `Repo.get` calls in tests
- `NoBareTruthinessAssert` — no `assert variable` without a comparison operator
- `TestsOwnTheirData` — tests that read from DB must also create their data

### Writing New Checks

1. Create the check in `lib/credo/checks/architecture/` or `lib/credo/checks/test_quality/`
2. Write tests in `test/credo/checks/` (same directory structure)
3. Register in `.credo.exs` under the `enabled` list
4. Set `exit_status: 0` for new checks until they're tuned (report as suggestions)

### Quick Commands

```bash
mix credo.changed --strict   # Credo on changed files only (fast)
make check-full              # Full compile + credo + test
make check-bg                # check-full in background with macOS notification
```
