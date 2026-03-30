---
status: raw
created: 2026-03-25
updated: 2026-03-30
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

## Dependency Changes

- Remove: `wallaby`
- Add: `phoenix_test` + `phoenix_test_playwright` (both `:test` only)
- Add: `playwright` npm package in `assets/`
- Install browsers: `npx --prefix assets playwright install chromium --with-deps`

## New E2ECase (single case template)

Replaces both `E2ECase` and `ProdDataE2ECase`:
- Start Playwright session via `PhoenixTest.Playwright.Case`
- Ecto sandbox in shared mode
- Prod data guard (minimum species count)
- Auth bypass for admin tests
- Area tags preserved for selective runs

## Test File Layout

```
test/e2e/
├── admin/
│   ├── admin_test.exs
│   ├── taxonomy_admin_test.exs  (from test/prod_data/e2e/)
│   └── reclassify_test.exs      (from test/prod_data/e2e/)
├── auth/auth_test.exs
├── browse/browse_test.exs
├── public/
│   ├── public_pages_test.exs
│   └── smoke_test.exs           (from test/prod_data/e2e/)
└── search/search_test.exs
```

## API Translation

Simple tests (21 in test/e2e/) — near 1:1:
- `visit/assert_has/refute_has/click` map directly
- Drop `.phx-connected` waits (Playwright auto-waits)
- `css("sel", text: "X")` → `"sel", text: "X"`

Complex tests (21 in test/prod_data/e2e/) — try native first:
- `fill_taxonomy_field` → try `fill_in` or `type()`, fall back to `evaluate()` if LiveView doesn't respond
- `open_delete_modal` / `submit_taxonomy_form` → try `click_button`, fall back to `evaluate()` with execJS
- `search_and_select_family/genus` → try native type + click on results, fall back to `evaluate()` for component-targeted event pushes
- `confirm_cascade_delete` → try native type into confirmation input
- `wait_for_db` helper — keep as-is, not a Wallaby thing

## Config

test.exs: Remove Wallaby config. Add phoenix_test + phoenix_test_playwright config.
test_helper.exs: Replace Wallaby startup with Playwright supervisor.
runtime.exs: Keep GALLFORMERS_E2E=1 → server: true pattern.

## Makefile

- `make e2e` — all E2E (requires prod data)
- `make e2e-headed` — visible browser
- `make e2e-setup` — install Playwright browsers (replaces chromedriver check)
- Keep area targets, update scripts/e2e-changed
- Drop chromedriver check

## CI

- Remove chromedriver setup step from ci.yml
- Update test count expectations in mix.exs

## Cleanup

- Delete `test/support/prod_data_e2e_case.ex`
- Delete `test/prod_data/e2e/` (tests moved)
- Update CLAUDE.md and CODING_STANDARDS.md E2E sections

