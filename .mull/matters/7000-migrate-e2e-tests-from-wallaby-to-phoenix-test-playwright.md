---
status: raw
created: 2026-03-25
updated: 2026-03-25
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
- Actively maintained (v0.10.1, 10 releases, clear docs)

## Why not alternatives

- **Wallaby.Selenium + Firefox**: requires pinning Selenium Server ≤4.8.0 (Wallaby only speaks legacy JSON Wire Protocol, W3C support is open issue since 2019). Dead end.
- **playwright-elixir (mechanical-orchard)**: still alpha after years, incomplete API coverage
- **Staying on Wallaby.Chrome**: chromedriver Homebrew cask dies Sep 2026, then manual installs forever

## Scope

- ~21 E2E tests in `test/e2e/` (public + admin)
- Replace `wallaby` dep with `phoenix_test_playwright` + `phoenix_test`
- Rewrite tests against PhoenixTest API
- Update E2ECase support module
- Update Makefile targets (make e2e, make e2e-headed, etc.)
- Update CI workflow (install Playwright browsers instead of chromedriver)
- Remove Wallaby config from test.exs
- Update CLAUDE.md and CODING_STANDARDS.md E2E sections

## Open questions

- Does phoenix_test_playwright support headed mode for debugging? (Wallaby has E2E_HEADED=1)
- Screenshot-on-failure support? (currently via Wallaby config)
- Any PhoenixTest API gaps vs Wallaby for our test patterns?

## References

- https://hex.pm/packages/phoenix_test_playwright
- https://hexdocs.pm/phoenix_test_playwright/
- https://github.com/ftes/phoenix_test_playwright
- https://ftes.de/articles/2024-11-14-using-playwright-in-elixir

