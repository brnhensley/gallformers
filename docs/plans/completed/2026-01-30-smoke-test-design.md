# Smoke Test Mix Task - Design Document

**Date:** 2026-01-30
**Issue:** gallformers-okhy
**Purpose:** Automated verification of critical V2 functionality before and after DNS cutover

## Overview

A Mix task that runs automated smoke tests against a Gallformers deployment to verify core functionality is working. Designed for quick verification during DNS cutover from V1 to V2.

## Command Interface

```bash
mix smoke_test https://gallformers.fly.dev   # Pre-cutover
mix smoke_test https://gallformers.org        # Post-cutover
```

## Architecture

- **Location:** `lib/mix/tasks/smoke_test.ex`
- **HTTP Client:** Req (already in dependencies)
- **Execution:** Sequential test execution
- **Failure Handling:** Continue on failure, report all results
- **Exit Code:** 0 if all pass, 1 if any fail
- **Timeout:** 10 seconds per request, no retries

## Test Suite

### Phase 1: Core Health & API
1. `/health` - Verify 200 OK, body contains "ok"
2. `/api/v2/stats` - Verify 200 OK, JSON has `species_count` > 0

### Phase 2: Dynamic Resource Discovery
3. `/api/v2/galls` - Get first gall ID from results
4. `/api/v2/hosts` - Get first host ID from results
5. `/api/v2/families` then `/api/v2/genera/:id` - Get first genus ID

### Phase 3: Public Pages
6. `/` (home) - Verify 200 OK, contains "Gallformers"
7. `/gall/:id` - Verify 200 OK, contains "Host" or "Description"
8. `/host/:id` - Verify 200 OK, contains scientific name pattern
9. `/genus/:id` - Verify 200 OK, contains genus name

### Phase 4: Search Functionality
10. `/api/v2/search?q=weldi` - Verify JSON response with results array
11. `/globalsearch?q=weldi` - Verify page loads, contains search results

### Phase 5: Static Assets
12. `/assets/app.css` - Verify 200 OK, content-type: text/css
13. `/assets/app.js` - Verify 200 OK, content-type: application/javascript
14. Extract image URL from gall page, verify CloudFront URL resolves

## Implementation Structure

### Module Layout

```elixir
defmodule Mix.Tasks.SmokeTest do
  use Mix.Task

  @shortdoc "Run smoke tests against a deployment"

  def run([base_url]), do: execute(base_url)
  def run(_), do: print_usage()

  defp execute(base_url)
  defp run_checks(base_url)
  defp print_results(results)
  defp exit_with_code(results)
end
```

### Test Definition Structure

```elixir
%{
  name: "Health check",
  path: "/health",
  method: :get,
  expect_status: 200,
  expect_content: "ok",
  timeout: 10_000
}
```

### Dynamic Tests

After discovery phase, store IDs in map:
```elixir
%{gall_id: 1, host_id: 2, genus_id: 3}
```

Generate dynamic test definitions via `build_dynamic_tests(ids)`.

### HTTP Client Setup

```elixir
Req.new(
  base_url: base_url,
  receive_timeout: 10_000,
  retry: false
)
```

### Error Handling

- Catch HTTP errors (timeouts, connection refused, 4xx, 5xx)
- Mark test as failed with error message
- Continue to next test
- Never halt execution early

## Output Format

### Startup
```
Running smoke tests against https://gallformers.fly.dev
```

### Real-time Feedback
```
✓ Health check (/health)
✓ API stats (/api/v2/stats)
✓ Discover gall ID (/api/v2/galls) → found ID 1
✓ Discover host ID (/api/v2/hosts) → found ID 5
✓ Discover genus ID (/api/v2/families) → found ID 2
✓ Home page (/)
✓ Gall page (/gall/1)
✗ Host page (/host/5) - 404 Not Found
✓ Genus page (/genus/2)
✓ Search API (/api/v2/search?q=weldi)
✓ Search UI (/globalsearch?q=weldi)
✓ Static CSS (/assets/app.css)
✓ Static JS (/assets/app.js)
✗ Image gallery - CloudFront URL failed: connection timeout
```

### Summary
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
14 checks, 12 passed, 2 failed
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Usage During DNS Cutover

**Pre-cutover verification:**
```bash
mix smoke_test https://gallformers.fly.dev
```

**Post-cutover verification:**
```bash
mix smoke_test https://gallformers.org
```

**Note:** DNS propagation may take 5-10 minutes. Connection errors immediately after cutover are expected.

## Dependencies

- `Req` HTTP client (already in mix.exs)
- No new dependencies required

## Limitations

- Auth/admin routes not tested (require login session)
- Manual verification needed for authenticated functionality
- Could be enhanced later with Auth0 token flow if needed

## Future Enhancements (Not in Scope)

- Add timing information for performance monitoring
- CI integration for periodic health checks
- JSON output mode for machine parsing
- Authenticated endpoint testing
- Configurable test suite via flags
