# Plan: Extend Rate Limiting to All Routes

## Context

An Amazon crawler burst (842 requests in 2 min from AWS IPs with fake browser UAs) triggered
a cascade of memory pressure and OOM on Feb 15. The existing `RateLimiter` plug only covers
`/api/v2/*` routes. Browser/LiveView routes — the ones actually under attack — have zero rate
limiting. This change extends rate limiting to browser routes.

## Approach

Refactor the existing `RateLimiter` plug to be configurable, then add it to the `:browser`
pipeline with appropriate limits.

## Changes

### 1. Refactor `lib/gallformers_web/plugs/rate_limiter.ex`

Make the plug accept options for different contexts:

- `init/1` accepts `:scope` (atom used as bucket prefix) and `:limit` (requests per minute)
- `call/2` uses the configured scope/limit
- Fix IP detection to check `fly-client-ip` first (matches Analytics and RequestLogger plugs)
- Response format based on content type: JSON for API, HTML redirect for browser
- For browser 429s: render the 429 error template via `Phoenix.Controller`

Usage:
```elixir
# In router
pipeline :browser do
  ...
  plug GallformersWeb.Plugs.RateLimiter, scope: :browser, limit: 60
end

# API stays as-is but with explicit opts
pipe_through [:api, {GallformersWeb.Plugs.RateLimiter, scope: :api, limit: 100}]
```

Default if no opts: `scope: :api, limit: 100` (backward compatible).

### 2. Add `lib/gallformers_web/controllers/error_html/429.html.heex`

Styled matching the existing 404/403 pages — Gallformers branding, helpful message,
"Go Back" and "Go Home" buttons. No image needed, keep it simple.

### 3. Update `lib/gallformers_web/router.ex`

- Add `RateLimiter` to the `:browser` pipeline with `scope: :browser, limit: 60`
- Update the API usage to pass explicit `scope: :api, limit: 100`

**Limit rationale**: 60 req/min per IP for browser is generous for real users (1 req/sec
sustained) but stops crawlers doing 200+ req/min. The Amazon burst was ~420 req/min from
a single IP.

### 4. Add tests in `test/gallformers_web/plugs/rate_limiter_test.exs`

- Test that requests under limit pass through
- Test that requests over limit get 429
- Test browser scope returns HTML
- Test API scope returns JSON
- Test `fly-client-ip` header is preferred over `x-forwarded-for`

## Files Modified

| File | Change |
|------|--------|
| `lib/gallformers_web/plugs/rate_limiter.ex` | Refactor for configurable scope/limit, fix IP detection, content-type-aware responses |
| `lib/gallformers_web/router.ex` | Add RateLimiter to `:browser` pipeline, update API pipeline |
| `lib/gallformers_web/controllers/error_html/429.html.heex` | New 429 page |
| `test/gallformers_web/plugs/rate_limiter_test.exs` | New test file |

## Verification

```bash
mix test test/gallformers_web/plugs/rate_limiter_test.exs
mix precommit
```
