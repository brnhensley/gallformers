---
status: done
created: 2026-03-25
updated: 2026-04-01
epic: platform
relates: [1501]
---

# Migrate E2E tests from Wallaby to phoenix_test_playwright

## Context

Chrome removed from dev machine (constant telemetry, resource abuse). Homebrew Chromium
cask deprecated (fails Gatekeeper, disabled 2026-09-01). Homebrew chromedriver cask also
deprecated (same deadline). Current Wallaby + ChromeDriver setup has an expiration date.

Ungoogled Chromium (notarized builds) is the interim fix. This matter tracks the permanent
solution: migrate to Playwright, which manages its own browsers and eliminates the
chromedriver/Gatekeeper dependency chain entirely.

## Why phoenix_test_playwright

- Uses PhoenixTest API — tests read like integration tests, not Selenium scripts
- Playwright manages browser binaries itself (`npx playwright install`) — no chromedriver version matching, no Homebrew cask dependencies, no Gatekeeper issues
- Supports Chromium, Firefox, AND WebKit (Safari) from a single test suite
- Built-in Ecto sandbox support (same user-agent metadata pattern as Wallaby)
- Actively maintained (v0.13.0, clear docs)

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| `execute_script` workarounds | Hybrid — try native Playwright first, fall back to `evaluate()` | Playwright's `type()` simulates real keystrokes that should fire phx-change. But component-targeted event pushes may still need JS. |
| Test structure | Consolidate into single `test/e2e/` directory | Two suites = missed tests, double maintenance. Agents and humans both overlook the prod_data E2E tests. |
| Data | All E2E tests run against prod data copy | Prod data tests need real data. Simple tests work fine against it too. One data setup, one case template. |
| CI | E2E stays out of CI — local preflight only | E2E never really ran separately. Adding prod data download to CI adds complexity for little value. |

## Implementation Plan

**Goal:** Replace Wallaby + ChromeDriver with phoenix_test_playwright across all 42 browser tests, consolidating two test suites into one.

**Architecture:** Single `test/e2e/` directory, one case template (E2ECase), all tests run against prod data copy. Playwright manages its own browser binaries. E2E excluded from CI entirely.

**Tech Stack:** phoenix_test ~> 0.4, phoenix_test_playwright ~> 0.12, Playwright (npm, in assets/)

### Task 1: Infrastructure — deps, config, case template

**Files:**
- Modify: `mix.exs` — remove `wallaby`, add `phoenix_test` + `phoenix_test_playwright`
- Modify: `assets/package.json` — add `playwright` dev dependency
- Modify: `config/test.exs` — remove Wallaby config (lines 39-60), add phoenix_test + phoenix_test_playwright config
- Modify: `test/test_helper.exs` — replace Wallaby startup with Playwright supervisor
- Modify: `test/support/e2e_case.ex` — rewrite for Playwright (consolidated, replaces both old case templates)

**Behavior:**

mix.exs: Replace `{:wallaby, "~> 0.30", only: :test, runtime: false}` with:
```elixir
{:phoenix_test, "~> 0.4", only: :test, runtime: false},
{:phoenix_test_playwright, "~> 0.12", only: :test, runtime: false}
```

assets/package.json: Add `"playwright": "latest"` to devDependencies. Then run `npx --prefix assets playwright install chromium --with-deps`.

config/test.exs: Remove the entire `config :wallaby` block. Add:
```elixir
config :phoenix_test, otp_app: :gallformers

config :phoenix_test_playwright,
  browser: :chromium,
  headless: System.get_env("E2E_HEADED") != "1",
  screenshot: true
```

test/test_helper.exs: Replace Wallaby block with:
```elixir
if System.get_env("GALLFORMERS_E2E") == "1" do
  {:ok, _} = PhoenixTest.Playwright.Supervisor.start_link()
  Application.put_env(:phoenix_test, :base_url, GallformersWeb.Endpoint.url())
end
```

E2ECase rewrite — the new case template must:
- Integrate PhoenixTest.Playwright for session creation (the test receives `conn` not `session`)
- Set up Ecto sandbox in shared mode
- Guard on minimum species count (prod data loaded)
- Enable auth bypass for admin-tagged tests
- Provide `on_exit` cleanup for auth bypass

**Gotcha:** `PhoenixTest.Playwright.Case` is itself a CaseTemplate. Nesting two CaseTemplates doesn't work in ExUnit. Either have tests `use PhoenixTest.Playwright.Case` directly with our setup in a shared `setup` block, or build our E2ECase from the Playwright primitives without using their Case module. Check `PhoenixTest.Playwright.Case` source to determine the right approach.

**Testing:** Run `make e2e-setup` (updated in Task 5, but manually verify `npx --prefix assets playwright install chromium` works). Write one smoke test to confirm Playwright can visit "/" and assert on "h1". This validates the full chain: deps → config → supervisor → browser → page load.

**Notes:** Keep `GALLFORMERS_E2E=1` → `server: true` pattern in runtime.exs unchanged. Keep port 4002.

---

### Task 2: Migrate simple E2E tests (5 files + smoke)

Depends on: Task 1

**Files:**
- Modify: `test/e2e/public/public_pages_test.exs` — rewrite for Playwright API
- Modify: `test/e2e/search/search_test.exs` — rewrite for Playwright API
- Modify: `test/e2e/browse/browse_test.exs` — rewrite for Playwright API
- Modify: `test/e2e/auth/auth_test.exs` — rewrite for Playwright API
- Modify: `test/e2e/admin/admin_test.exs` — rewrite for Playwright API
- Move: `test/prod_data/e2e/smoke_test.exs` → `test/e2e/public/smoke_test.exs`

**Behavior:**

API translation for all simple tests:
- `%{session: session}` → `%{conn: conn}`
- `css("selector")` → `"selector"` (plain string)
- `css("selector", text: "X")` → `"selector", text: "X"`
- `assert_has(session, css(".phx-connected"))` → remove entirely (Playwright auto-waits for page load)
- `click(link("text"))` → `click_link("text")`
- `refute_has(css("sel", text: "X"))` → `refute_has("sel", text: "X")`
- `assert_has(Query.text("not found"))` → check if `assert_has(text: "not found")` works, or use a broad selector like `"body", text: "not found"`
- `css("sel", count: :any)` → remove the count option; if asserting at least one exists, `assert_has("sel")` suffices

Remove all `Wallaby.Query` aliases and imports.

smoke_test.exs: Move file, change module name from `GallformersWeb.ProdDataE2E.SmokeTest` to `GallformersWeb.E2E.SmokeTest`, change `use GallformersWeb.ProdDataE2ECase` to `use GallformersWeb.E2ECase`, change `@moduletag :prod_data` to `@moduletag :e2e` + `@moduletag :e2e_public`.

browse_test.exs special case: Uses `Gallformers.Galls.list_galls()` and `Plants.list_hosts()` to find test data. With prod data these will return real records. Should work as-is.

**Testing:** Run `make e2e` (once Task 5 wires it up) or manually: `GALLFORMERS_E2E=1 mix test test/e2e --include e2e`. All 21 simple tests + 2 smoke tests should pass.

---

### Task 3: Migrate taxonomy_admin_test.exs

Depends on: Task 1

**Files:**
- Move: `test/prod_data/e2e/taxonomy_admin_test.exs` → `test/e2e/admin/taxonomy_admin_test.exs`

**Behavior:**

Module rename: `GallformersWeb.ProdDataE2E.TaxonomyAdminTest` → `GallformersWeb.E2E.TaxonomyAdminTest`
Tags: Replace `@moduletag :prod_data` with `@moduletag :e2e` + `@moduletag :e2e_admin`
Case template: `use GallformersWeb.E2ECase`
Session: `%{session: session}` → `%{conn: conn}` throughout

**Interaction helper rewrites (the hard part):**

`wait_for_liveview(session)` — Remove entirely. Playwright auto-waits. Delete all call sites.

`wait_for_db(condition, opts)` — Keep as-is. Pure Elixir, no Wallaby dependency.

`open_delete_modal(session)` — Currently uses `execute_script` to push a LiveView event via `liveSocket.execJS`. Try native first: `click_button(conn, "Delete")` or `click(conn, "button", text: "Delete")` — if the delete button is a standard phx-click button, Playwright should handle it. If not, translate to `evaluate(conn, js_string)`. Note: `evaluate` may handle args differently than `execute_script` — check the PhoenixTest.Playwright docs for how to pass arguments.

`confirm_cascade_delete(session, name)` — Currently injects value via JS + dispatches input event + pushes confirm event via execJS. Try native: `type(conn, "#delete-confirmation", name)` to simulate keystrokes (should fire the InputEvent hook), then `click_button(conn, "Delete")` or equivalent submit button. If the InputEvent hook doesn't respond to Playwright keystrokes, fall back to `evaluate()`.

`fill_taxonomy_field(session, field, value)` — Currently sets value + pushes validate event via execJS because Wallaby's fill_in doesn't fire phx-change. Try native: `fill_in(conn, "taxonomy[field]", with: value)` — Playwright simulates real user input that should trigger phx-change. If it doesn't, fall back to `evaluate()`.

`submit_taxonomy_form(session)` — Currently pushes "save" event via execJS. Try native: `click_button(conn, "Save")`. If the form has a standard submit button with phx-submit, this should work.

**DB query helpers:** `find_small_genus`, `find_small_family`, etc. — keep unchanged. Pure Ecto, no Wallaby dependency.

**Testing:** All 11 taxonomy admin tests should pass. Key verification: genus rename creates aliases, cascade delete removes records, collision is rejected. The DB assertions are the real test — if the browser interactions fire correctly, the DB state will be right.

**Notes:** This is the discovery task. Document which interaction patterns work natively and which need `evaluate()`. The findings directly apply to Task 4.

---

### Task 4: Migrate reclassify_test.exs

Depends on: Task 3 (for interaction pattern findings)

**Files:**
- Move: `test/prod_data/e2e/reclassify_test.exs` → `test/e2e/admin/reclassify_test.exs`

**Behavior:**

Module rename: `GallformersWeb.ProdDataE2E.ReclassifyTest` → `GallformersWeb.E2E.ReclassifyTest`
Tags: Replace `@moduletag :prod_data` with `@moduletag :e2e` + `@moduletag :e2e_admin`
Case template: `use GallformersWeb.E2ECase`
Session: `%{session: session}` → `%{conn: conn}` throughout

**Interaction helper rewrites:**

`wait_for_liveview(session)` — Remove entirely, same as Task 3.

`open_reclassify_modal(session)` — Currently: `click(css("button", text: "Rename/Reclassify"))`. Translate to: `click_button(conn, "Rename/Reclassify")`. Should work natively.

`push_to_component(session, event, payload)` — Currently uses `execute_script` to find component CID and push events. This is component-targeted event pushing — unlikely to have a native Playwright equivalent. Translate to `evaluate(conn, js_string)`. Args passing: check whether `evaluate` accepts arguments like `execute_script` did. May need to interpolate the event/payload into the JS string instead.

`search_and_select_family/genus(session, name)` — Uses `push_to_component` for clear/search events, then `click(css("#results button", count: :any, at: 0))`. The push_to_component calls will likely stay as evaluate(). For the click: `click(conn, "#reclassify-family-picker-results button:first-of-type")` or similar CSS pseudo-selector to replace `count: :any, at: 0`.

`set_epithet(session, value)` — Delegates to `push_to_component`. Same treatment as above.

`click_reclassify_save/cancel(session)` — Currently: `click(css("#reclassify-modal button", text: "Save"))`. Translate to: `click_button(conn, "#reclassify-modal button", text: "Save")` or `click(conn, "#reclassify-modal button", text: "Save")`.

`css("sel", visible: true)` — Used in `refute_has(css("#reclassify-modal", visible: true))`. Check PhoenixTest.Playwright docs for visibility assertions. May need to assert the modal element is absent from DOM (since the component uses `:if={@show}` which removes it entirely).

**DB query helpers:** Keep unchanged. Pure Ecto.

**Testing:** All 8 reclassify tests should pass. Key verification: genus changes cascade to species names, aliases are created, collisions are rejected, no-ops leave data unchanged.

**Notes:** The `push_to_component` helper is the pattern most likely to need `evaluate()` — it's pushing events to a specific LiveComponent CID, which has no native browser equivalent.

---

### Task 5: Makefile, CI, scripts, test counts

Depends on: Tasks 2-4 (all tests migrated)

**Files:**
- Modify: `Makefile` — rewrite E2E section, update preflight, update help
- Modify: `.github/workflows/ci.yml` — remove chromedriver step
- Modify: `mix.exs` — update `check_test_exclusions` function
- Modify: `scripts/e2e-changed` — remove chromedriver check, update test paths and tags

**Behavior:**

Makefile E2E section rewrite:
- `e2e-setup`: Replace chromedriver check with `npx --prefix assets playwright install chromium --with-deps`
- `check_chromedriver` helper: Delete entirely
- `e2e`: Load prod data into test DB, run `GALLFORMERS_E2E=1 mix test test/e2e --include e2e`, restore test DB after
- `e2e-headed`: Same as `e2e` but with `E2E_HEADED=1`
- `e2e-slow`: Same as `e2e-headed` but add `--trace` (Playwright has native slow_mo, could also set that in config)
- Area targets (`e2e-public`, `e2e-admin`, etc.): Same load-run-restore pattern, scoped to subdirectory
- `e2e-changed`: Same load-run-restore pattern, delegates to updated script
- `test-prod-data-e2e`: Delete this target (merged into `e2e`)
- `test-prod-data-all`: Simplify to just run context tests + `make e2e`
- `preflight`: Update to run `ci` then `make e2e` then `make test-prod-data` (context only)
- `help`: Update E2E section text

The load-run-restore pattern (extract to a Make helper or repeat):
```makefile
e2e: load-prod-data-test
	@echo "Running all E2E tests..."
	@GALLFORMERS_E2E=1 mix test test/e2e --include e2e; \
		status=$$?; \
		echo "Restoring test database..."; \
		$(MAKE) test-db; \
		exit $$status
```

ci.yml: Remove lines 86-90 (chromedriver setup step). No replacement needed — E2E tests don't run in CI.

mix.exs `check_test_exclusions`: E2E tests can no longer be included in this check (they need prod data which CI doesn't have). Update expected count to exclude E2E tests. Remove `GALLFORMERS_E2E` env setup. Update the expected total comment.

scripts/e2e-changed: Remove chromedriver check (lines 17-29). The `--all` path and area-to-directory mappings stay the same (test paths haven't changed). Update `--include e2e` (already correct). Add the load-prod-data-test + restore pattern, or have the script delegate to Make targets that handle it.

**Testing:** `make e2e` should load prod data, run all 42 tests, restore test DB. `make e2e-admin` should run only admin area tests. `make e2e-headed` should open a visible browser.

---

### Task 6: Cleanup and documentation

Depends on: Tasks 2-5

**Files:**
- Delete: `test/support/prod_data_e2e_case.ex`
- Delete: `test/prod_data/e2e/` directory (all 3 files moved in Tasks 2-4)
- Modify: `CODING_STANDARDS.md` — update E2E section
- Modify: `CLAUDE.md` (project root) — update E2E documentation

**Behavior:**

Delete `test/support/prod_data_e2e_case.ex` — fully replaced by consolidated E2ECase.

Delete `test/prod_data/e2e/` — all files moved to `test/e2e/`. Verify the directory is empty before deleting.

CODING_STANDARDS.md E2E section: Replace Wallaby references with Playwright. Update:
- Prerequisites: `npx playwright install chromium` instead of chromedriver
- Example test pattern: use PhoenixTest API (`conn`, string selectors)
- Running instructions: all Make targets
- Note that all E2E tests require prod data

CLAUDE.md E2E section: Update test types table (E2E now uses Playwright), update make commands, update test count expectations, remove Wallaby references from prerequisites, update the E2E test running documentation.

**Testing:** `mix compile --warnings-as-errors` to verify no dead references to Wallaby or deleted modules. `make e2e` full run to confirm everything still works after cleanup.
