# Built-in Analytics Design

**Date:** 2026-01-29
**Status:** Approved

## Overview

Add privacy-respecting analytics built directly into the Phoenix app. No third-party services, no cookies, no individual tracking.

## Goals

- Track page views with referrer and device context
- Count unique visitors without storing identifiable data
- Provide an admin dashboard for viewing stats
- Zero impact on page load performance

## Non-Goals

- Feature/event tracking (can add later)
- Real-time dashboards
- Fancy charts (tables are fine)

## Schema

**Table: `page_views`**

| Column | Type | Purpose |
|--------|------|---------|
| `id` | integer | Primary key |
| `path` | string | Page path (e.g., `/species/123`) |
| `referrer_host` | string, nullable | Referrer domain only (e.g., `google.com`) |
| `browser` | string | Browser family (`Chrome`, `Firefox`, `Safari`, etc.) |
| `device_type` | string | `desktop`, `mobile`, or `tablet` |
| `visitor_hash` | string | Daily anonymous hash for unique counting |
| `inserted_at` | utc_datetime | Timestamp |

**Indexes:**

- `inserted_at` - for date range queries
- `path` - for top pages queries
- `visitor_hash, inserted_at` - for unique visitor counts

## Privacy Approach

**Unique visitor tracking without storing IPs:**

Generate: `sha256(date + ip + user_agent)`

This produces a hash that:
- Allows counting unique visitors per day
- Cannot be reversed to get the IP
- Does not track users across days
- Is the same approach used by Plausible and similar privacy-focused tools

**Referrer:**

Store only the host domain (`google.com`) not the full URL. This avoids leaking search queries or other sensitive referrer data.

## Tracking Implementation

### HTTP Requests (Plug)

A Plug in the `:browser` pipeline captures initial page loads:

```elixir
pipeline :browser do
  # ... existing plugs
  plug GallformersWeb.Plugs.Analytics
end
```

The Plug:
- Runs after the response is sent
- Spawns an async Task to write the record
- Never blocks or slows down the response

### LiveView Navigations (on_mount)

LiveView navigations happen over WebSocket and bypass the Plug. A single `on_mount` hook handles these:

```elixir
live_session :default, on_mount: [GallformersWeb.Analytics.TrackPageView] do
  # all live routes
end
```

### Exclusions

Do not track:
- Static assets (`/assets/*`, `/images/*`, favicons, robots.txt)
- API endpoints (`/api/*`)
- Admin pages (`/admin/*`)
- Known bots (Googlebot, bingbot, Slurp, DuckDuckBot, etc.)
- Health check endpoints

## Admin Dashboard

**Route:** `/admin/analytics`

### Stats Summary (top of page)

| Metric | Today | Last 7 Days | Last 30 Days |
|--------|-------|-------------|--------------|
| Page Views | X | X | X |
| Unique Visitors | X | X | X |

### Tables

**Top Pages:**
- Path, view count, unique visitors
- Sorted by views descending

**Referrers:**
- Host domain (or "Direct" for null)
- View count
- Sorted by views descending

**Devices:**
- Device type, count, percentage

**Browsers:**
- Browser family, count, percentage

### Filtering

- Date range: Today, Last 7 days, Last 30 days, Custom range
- Optional path prefix filter (e.g., show only `/species/*`)

## Files to Create

| File | Purpose |
|------|---------|
| `lib/gallformers/analytics.ex` | Context module (queries, aggregations) |
| `lib/gallformers/analytics/page_view.ex` | Ecto schema |
| `priv/repo/migrations/*_create_page_views.exs` | Migration |
| `lib/gallformers_web/plugs/analytics.ex` | HTTP request tracking |
| `lib/gallformers_web/analytics/track_page_view.ex` | LiveView on_mount hook |
| `lib/gallformers_web/live/admin/analytics_live.ex` | Dashboard LiveView |

## Data Retention

Keep all raw data indefinitely. SQLite handles millions of rows fine with proper indexes. Can add roll-up aggregation later if needed.

## Dependencies

**User agent parsing:**

Need a library to parse user agent strings into browser family and device type. Options:
- `ua_inspector` - full-featured, uses external data files
- `browser` - simpler, pure Elixir

Recommend `browser` for simplicity.

## Future Enhancements (not in scope)

- Event tracking (search queries, filter usage, etc.)
- Export to CSV
- Sparkline charts
- Email reports
