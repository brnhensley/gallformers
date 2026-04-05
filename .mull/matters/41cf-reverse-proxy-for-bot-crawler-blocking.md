---
status: planned
created: 2026-04-02
updated: 2026-04-02
epic: platform
---

# Reverse proxy for bot/crawler blocking

## Context

Three bot-related incidents in 6 weeks (Feb 18 OOM, March 24 outage, April 2 down alert). App-level defenses (robots.txt, API rate limiting) are insufficient — bad actors ignore robots.txt and requests consume app resources before any rate limiting kicks in.

App-level rate limiting (matter 220d) is deprioritized — by the time a request hits the BEAM, the damage is done.

## Decision

Self-hosted reverse proxy on Fly.io. No third-party CDN/WAF vendors (Cloudflare etc.) — avoid centralization and vendor dependency.

## Architecture

- Separate Fly app (`gallformers-proxy`), 256MB shared-cpu in ewr (~$2/mo)
- Proxies to `gallformers.internal` over Fly 6PN private network
- `gallformers` app made internal-only (no public IP)
- DNS for www.gallformers.org points to the proxy app
- Proxy handles TLS termination (Fly manages certs on the proxy app)

## Key requirements

- CIDR-based IP blocking (e.g. Meta crawler fleet: `2a03:2880::/32`)
- User-agent blocking (known bad scrapers, rotating-UA botnets)
- WebSocket proxying for LiveView (upgrade handling)
- Health check pass-through to backend `/health`
- Low latency — same region, sub-millisecond hop
- Blocklist changes deploy independently of the app

## Proxy choice — to evaluate

- **Caddy**: simple config, automatic HTTPS, Go binary (~40MB), built-in reverse proxy
- **nginx**: battle-tested, lowest resource usage, more config to write
- Either handles WebSocket proxying fine

## Blocklist — known offenders from incidents

- Meta crawlers: `2a03:2880::/32` (IPv6) — ignores robots.txt, 74 req/min bursts
- Amazonbot rotating-UA scraper pattern (2,232 IPs in one burst April 2)
- SEO bots already in robots.txt: AhrefsBot, SemrushBot, SERankingBacklinksBot, MJ12bot, DotBot

## Open questions

- Rate limiting at the proxy level vs. just blocklisting?
- How to handle the Amazonbot-style distributed scrapers (thousands of IPs, rotating UAs)?
- Log forwarding — proxy access logs to the app volume or separate?
- Cutover plan — how to switch DNS with minimal downtime

