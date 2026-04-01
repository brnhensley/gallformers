# Background Job Processing Research: Oban & Alternatives

Research date: 2026-03-21

## Context

Gallformers needs background job processing for document extraction (matter 7fda), image processing (matter 16bb), and potentially other async workflows. The project currently uses plain GenServers for recurring work (analytics rollup, health watchdog) with no job queue library. Stack: Phoenix 1.8, PostgreSQL, single node on Fly.io.

---

## The Landscape

Oban OSS is the de facto standard for background jobs in Elixir (66% adoption in the 2025 State of Elixir survey). Everything else is either dead, niche, or just OTP primitives.

### Download Activity (Hex.pm, 90-day, March 2026)

| Library | Downloads | Last Release | Backend |
|---------|-----------|-------------|---------|
| **Oban** | 1,269,019 | Jan 2026 (v2.20.3) | PostgreSQL, SQLite, MySQL |
| **Broadway** | 542,244 | Feb 2025 (v1.2.1) | N/A (pipeline framework) |
| **Quantum** | 271,931 | Feb 2024 (v3.5.3) | None (in-memory) |
| **Exq** | 81,041 | Nov 2025 (v0.23.0) | Redis |
| Honeydew | ~dead | May 2021 | Mnesia/Ecto |
| Rihanna | ~dead | Dec 2020 | PostgreSQL |
| EctoJob | ~dead | Sep 2020 | PostgreSQL + GenStage |
| Toniq | ~dead | Feb 2018 | Redis |

---

## Oban OSS (Free, Apache 2.0)

The OSS version is not a crippled teaser. It is a full production system.

### Features Included in OSS

| Feature | Details |
|---------|---------|
| **Persistent jobs** | Stored in Postgres via `oban_jobs` table |
| **Transactional enqueue** | Insert jobs inside Ecto transactions -- if the txn rolls back, the job never exists |
| **Named queues** | Independent concurrency limits per queue (`emails: 20, extraction: 1`) |
| **Retries** | Configurable max attempts, exponential backoff, error history per job |
| **Scheduling** | Future-scheduled jobs with second-level precision |
| **Cron** | Built-in periodic job plugin, cluster-safe (no duplicate enqueuing across nodes) |
| **Uniqueness** | Prevent duplicate jobs by args/worker/period |
| **10 priority levels** | Within each queue |
| **Telemetry** | Full lifecycle events for monitoring |
| **Web dashboard** | Oban Web went Apache 2.0 in January 2025 -- free monitoring UI |
| **Plugins** | Pruner (cleanup), Reindexer (prevent bloat), Lifeline (rescue orphans), Stager |
| **Testing** | Three modes: inline (sync), manual (explicit drain), disabled |
| **Runtime control** | Pause/resume/scale queues without restart, across nodes |

**Throughput**: ~17,700 jobs/sec benchmarked. Document extraction use case would be dozens per day.

### Architecture

- Jobs stored in `oban_jobs` table in your existing database
- Job claiming uses `SELECT ... FOR UPDATE SKIP LOCKED` -- zero contention, no deadlocks
- `LISTEN/NOTIFY` for real-time dispatch (sub-second latency), periodic polling as fallback
- Each job runs in a dedicated Erlang process for isolation
- Leader election via upsert on `oban_peers` table for cluster-safe periodic tasks
- Job lifecycle: insert -> notify -> fetch (SKIP LOCKED) -> execute -> ack (batch)

---

## Oban Pro ($135/mo)

| Feature | What it does | Relevant to gallformers? |
|---------|-------------|--------------------------|
| **Smart Engine** | Global concurrency/rate limiting across all nodes | No -- single node |
| **Workflows** | DAG-based job dependencies (fan-out, fan-in) | No -- sequential pipeline |
| **Batches** | Group jobs with completion callbacks | No |
| **Dynamic Partitioner** | Table partitioning for millions of jobs/day | No |
| **Pro Worker** | Encrypted args, output recording, execution hooks | No |
| **Decorators** | Build jobs from regular functions | Nice-to-have, not needed |

Pro is enterprise-scale tooling targeting multi-node, high-throughput deployments. Nothing in gallformers' use case requires it.

---

## Licensing & Sustainability

### The Good

- **Oban OSS is Apache 2.0** -- irrevocably open source, community can fork anytime
- **Oban Web is Apache 2.0** (since January 2025)
- Features have only moved FROM paid TO free (Web went OSS). Never the reverse.
- 7 years old, actively maintained (3,800+ GitHub stars, 100+ contributors)
- The Sidekiq model (same OSS/Pro split in Ruby) has worked for 14 years with no feature clawbacks
- Parker Selbert has explicitly discussed continuity planning (Changelog podcast #35)

### The Concerning

- **Bus factor ~1.5** -- Parker Selbert writes ~99% of the code. Shannon handles business. Husband-and-wife shop outside Chicago.
- Pro source is proprietary -- if Sorentwo disappears, Pro updates stop (but OSS continues)
- Pro ToS has a 2-year non-compete clause (likely targets competing libraries, not end users, but language is broad)
- No known source escrow provisions for Pro customers
- The Pro hex repo (`getoban.pro/repo`) has gone down before, blocking CI pipelines

### Risk Assessment for Gallformers

Using only OSS Oban, the risk is minimal. Apache 2.0 means the code is permanently available. If Parker disappeared, the community would fork -- the codebase is mature and well-tested. The bus factor concern is real but no different from many Elixir ecosystem libraries.

---

## Alternatives Evaluated

### Exq (Redis-backed)

Actively maintained. Sidekiq wire-format compatible. Four releases in 2025.

**Why not**: Adds a Redis dependency for no benefit when you already have Postgres. No transactional enqueue (cannot atomically enqueue a job within the same DB transaction). 15x fewer downloads than Oban. Smaller community, fewer people who have debugged edge cases.

**When it makes sense**: You already have Redis infrastructure, need Sidekiq interop, or Postgres is genuinely your bottleneck.

### Quantum (Cron-only)

In-memory cron-expression scheduler. No persistence, no retries, no queuing.

**Why not**: If the node is down when a job is due, that execution is simply missed. No retry, no history, no visibility. Oban's built-in cron plugin does everything Quantum does plus persistence.

**When it makes sense**: Trivial recurring tasks where missing an execution is acceptable and you don't want any library overhead. But a plain GenServer with `Process.send_after` does the same thing with zero dependencies.

### Broadway (Streaming Pipelines)

Actively maintained by Dashbit (Jose Valim's company). A concurrent, multi-stage data ingestion framework built on GenStage.

**Why not**: Different problem domain. Broadway consumes from external message queues (SQS, Kafka, RabbitMQ). It is not a "do this thing later" job queue -- it is a "process this stream of things" pipeline framework.

**When it makes sense**: ETL pipelines, consuming from Kafka/SQS, log processing, real-time data ingestion.

### Faktory (Polyglot Job Server)

Language-agnostic job server by Mike Perham (Sidekiq creator). Elixir clients exist but are fragmented.

**Why not**: Adds a separate server process. Oban gives the same capabilities without extra infrastructure. The "smart server, dumb client" architecture makes sense for languages without good concurrency primitives, but Elixir has the BEAM.

### Dead Libraries

- **Honeydew** (May 2021) -- Pluggable backends, interesting design, abandoned
- **Rihanna** (Dec 2020) -- PostgreSQL-backed, simple. Superseded by Oban.
- **EctoJob** (Sep 2020) -- Postgres + GenStage. Predecessor/inspiration for Oban's design.
- **Toniq** (Feb 2018) -- Redis-backed, long dead.
- **Kiq** (archived) -- Parker Selbert's own pre-Oban attempt with Redis. He tried Redis first, concluded Postgres was better, and built Oban.

---

## Rolling Your Own

### The Architecture is Well-Understood

Every modern Postgres job queue uses the same core pattern:

```sql
DELETE FROM jobs
WHERE id = (
  SELECT id FROM jobs
  WHERE status = 'available'
  ORDER BY created_at
  LIMIT 1
  FOR UPDATE SKIP LOCKED
)
RETURNING *;
```

`FOR UPDATE SKIP LOCKED` (PostgreSQL 9.5+) gives you race-free, deadlock-free concurrent job claiming. Workers that find a locked row skip it and grab the next one.

Add `LISTEN/NOTIFY` for immediate dispatch + periodic polling as fallback, and you have the foundation.

### What You'd Need to Build

1. Jobs table schema + migration
2. Enqueue function (ideally inside Ecto.Multi)
3. Claim query with SKIP LOCKED
4. GenServer poller with LISTEN/NOTIFY wakeup
5. Worker execution via Task.Supervisor
6. Retry logic with exponential backoff + jitter
7. Orphan detection (heartbeat/timeout reaper)
8. Pruning of completed jobs
9. Error tracking and dead letter handling

This is ~200 lines for a minimal version, but production-quality handling of edge cases (poison pills, connection pool exhaustion, orphaned jobs) adds significant complexity.

### Community Consensus

The community consensus is blunt: by the time you've built and debugged items 1-9, you've reimplemented Oban -- except worse, with fewer tests, and maintained by you alone. Multiple teams who built custom solutions (documented on ElixirForum and in blog posts) reported hitting walls around persistence across deploys, observability, distributed coordination, and retry semantics.

The Nimble team's case study is instructive: they built a custom GenServer-based system, hit database connection exhaustion and concurrency issues under load, replaced it with Oban, and solved both problems with configuration alone.

### When OTP Primitives ARE Sufficient

If ALL of these are true, a GenServer/Task.Supervisor approach works:

1. Missing a job execution is acceptable (not a business commitment)
2. Single node (or idempotent execution on multiple nodes is OK)
3. No need to schedule work for a specific future time
4. No need for job history or audit trails
5. Work is fast enough that losing in-flight jobs during deploys is tolerable

The gallformers analytics rollup and health watchdog are perfect examples -- they meet all five criteria. A document extraction pipeline that makes expensive LLM API calls does not.

---

## The "Postgres as Job Queue" Validation

### Rails Solid Queue

Rails 8 ships with Solid Queue as the default job backend -- a Postgres/MySQL-backed queue using `FOR UPDATE SKIP LOCKED`. 37signals runs **6 million jobs/day** on it for HEY email infrastructure:

- ~1,300 polling queries/sec
- Average query time: 110 microseconds
- Average rows examined per query: 0.02

### Cross-Ecosystem Trend

The industry has moved from "you need Redis" (Sidekiq dominance, 2012-2022) to "Postgres is probably fine" (GoodJob, Solid Queue, Oban, 2022-present). The inflection point was SKIP LOCKED maturity and the realization that most apps process far fewer than 100 jobs/second.

Consensus threshold: Postgres is comfortable up to ~10,000-50,000 jobs/second on modern hardware. Below 100 jobs/second, it's a no-brainer over Redis.

### Performance Concerns

The one real gotcha: **MVCC bloat**. Every UPDATE/DELETE creates dead tuples. High-churn queue tables need aggressive autovacuum:

```sql
ALTER TABLE oban_jobs SET (autovacuum_vacuum_scale_factor = 0.01);
```

Oban handles this with built-in Pruner (deletes old completed jobs) and Reindexer (rebuilds indexes concurrently) plugins. At gallformers' volume, bloat is a non-concern.

Connection pool: Oban shares your Ecto pool by default. For high-throughput apps, create a dedicated pool. At gallformers' scale, sharing is fine.

---

## Assessment for Gallformers

### What Already Works Fine (Keep As-Is)

- **Analytics.Rollup** -- GenServer with `Process.send_after` for nightly rollup. Perfect for recurring work where missing an execution means it catches up next time.
- **HealthWatchdog** -- GenServer for periodic health checks. No persistence needed.

### What Would Benefit from Oban OSS

- **Document extraction pipeline (7fda)** -- LLM API calls that are slow, can fail, cost money, need retry, need concurrency control
- **Image processing pipeline (16bb)** -- similar profile
- **Any future "process this reliably in the background" use case**

### What We Don't Need

- **Oban Pro** -- $135/mo for multi-node/high-scale features we won't use
- **Redis / Exq** -- adds infrastructure for no benefit when we have Postgres
- **A custom job queue** -- we'd just build a worse Oban
- **Broadway** -- we're not consuming from external message queues

### Decision Criteria

| Question | Answer | Implication |
|----------|--------|-------------|
| Can the user wait for document extraction? | No (LLM calls take 30-120s) | Need async processing |
| Is it OK to lose a job on deploy/crash? | No (LLM calls cost money) | Need persistence |
| Will it fail sometimes? | Yes (LLM APIs are flaky) | Need retry logic |
| Need to limit concurrency? | Yes (API rate limits) | Need queue with concurrency control |

All four answers point to "use a real job queue."

---

## Sources

### Oban Documentation & Official
- [Oban GitHub](https://github.com/oban-bg/oban) (3,853 stars, Apache 2.0)
- [Oban HexDocs](https://hexdocs.pm/oban/Oban.html)
- [Oban Scaling Guide](https://hexdocs.pm/oban/scaling.html)
- [Oban Pro Pricing](https://oban.pro/pricing)
- [Oban Pro Terms of Service](https://oban.pro/terms)
- [OSS Oban Web announcement](https://oban.pro/articles/oss-web-and-new-oban)
- [Self-hosting Oban packages](https://oban.pro/articles/self-hosting-oban-packages)
- [Changelog & Friends #35: The Oban Pros](https://changelog.com/friends/35)

### Community Discussion
- [ElixirForum: Background job queues -- when to use?](https://elixirforum.com/t/background-job-queues-when-to-use-when-not-to-use-which-one-to-use/20436)
- [ElixirForum: All batteries included OSS alternative](https://elixirforum.com/t/all-batteries-included-open-source-background-job-alternative/60254)
- [ElixirForum: Oban Web to be open sourced](https://elixirforum.com/t/oban-web-to-be-open-sourced/67100)
- [ElixirForum: Oban Pro 1.5.0 migration incident](https://elixirforum.com/t/oban-pro-1-5-0-migration-locked-our-production-table/70020)
- [ElixirForum: How do things like Oban Pro work?](https://elixirforum.com/t/how-do-things-like-oban-pro-work-in-elixir/63531)
- [State of Elixir 2025 Survey](https://elixir-hub.com/surveys/2025)

### Architecture & Patterns
- [Postgres job queues & MVCC failure](https://brandur.org/postgres-queues) (Brandur Leach)
- [River: fast Postgres job queue for Go](https://brandur.org/river)
- [The notifier pattern for Postgres apps](https://brandur.org/notifier)
- [Introducing Solid Queue (37signals)](https://dev.37signals.com/introducing-solid-queue/)
- [Solid Queue deep dive (AppSignal)](https://blog.appsignal.com/2025/06/18/a-deep-dive-into-solid-queue-for-ruby-on-rails.html)
- [FOR UPDATE SKIP LOCKED explained](https://www.inferable.ai/blog/posts/postgres-skip-locked)

### Comparisons & Evaluations
- [Nimble: choosing Elixir background job tooling](https://nimblehq.co/blog/the-journey-on-choosing-elixir-background-job-tooling)
- [Honeybadger: Elixir background jobs](https://www.honeybadger.io/blog/elixir-background-jobs/)
- [Oban starts where Tasks end](https://oban.pro/articles/oban-starts-where-tasks-end)
- [Mistakes Rails developers make in Elixir: background jobs](http://crevalle.io/mistakes-rails-developers-make-in-phoenix-pt-1-background-jobs.html) (Parker Selbert, pre-Oban)
- [BullMQ vs Oban benchmark](https://bullmq.io/articles/benchmarks/bullmq-elixir-vs-oban/)
- [GoodJob vs Sidekiq](https://betterstack.com/community/guides/scaling-ruby/goodjob-vs-sidekiq/)
- [Postgres is the only queue you need (until 50k jobs/sec)](https://medium.com/@harsh.vaghela.work/postgres-is-the-only-queue-you-need-until-50k-jobs-sec-5931611b551c)

### DIY / Roll-Your-Own
- [Implementing a Postgres job queue in less than an hour](https://aminediro.com/posts/pg_job_queue/)
- [Turning PostgreSQL into a queue serving 10,000 jobs/sec](https://gist.github.com/chanks/7585810)
- [DockYard: three retry patterns in Elixir](https://dockyard.com/blog/2019/04/02/three-simple-patterns-for-retrying-jobs-in-elixir)
- [AppSignal: background processing native Elixir approach](https://blog.appsignal.com/2019/05/14/elixir-alchemy-background-processing.html)
- [Cassava: roll your own queue with GenStage](https://gocassava.com/blog/roll-your-own-queue-processor-elixir-with-genstage)
