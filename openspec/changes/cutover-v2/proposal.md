# Change: Cutover from V1 to V2

## Why

After completing Phases 1-3 of the `rewrite-gallformers-v2` umbrella (Go API, Svelte Admin, Svelte Public), the new v2 stack running on Fly.io needs to replace the v1 Next.js stack running on Digital Ocean. This cutover must be executed carefully to:

- Minimize downtime (target: <10 minutes, acceptable: <30 minutes)
- Ensure zero data loss
- Preserve all public URLs (SEO critical)
- Provide rollback capability if issues discovered

## What Changes

### Cutover Scope

| Action | Description |
|--------|-------------|
| Database sync | Final sync of SQLite from DO volume to Fly.io volume |
| DNS switch | Update Namecheap DNS to point gallformers.org/com to Fly.io |
| Verification | Validate all critical paths work correctly |
| Rollback prep | Document and test rollback procedure |
| Deprecation | Remove v1 code, cancel DO Droplet |

### What Moves

- **gallformers.org** DNS: DO Droplet IP → Fly.io app
- **gallformers.com** DNS: DO Droplet IP → Fly.io app
- **Database**: DO mounted volume → Fly.io persistent volume

### What Stays

- **S3 images**: Continue using same bucket/paths
- **Auth0**: Same tenant, updated callback URLs

### **BREAKING** Changes

- None for end users (URLs preserved)
- v1 codebase deleted from repository
- DO infrastructure decommissioned

## Impact

- **Affected specs**: `v2-infrastructure` (adds cutover requirements)
- **Affected code**: Repository structure (v1 removal, v2 promotion)
- **Dependencies**: Requires all Phase 1-3 proposals complete and deployed
- **Risk**: Medium - mitigated by rollback procedure and staged approach

## Dependencies

**Must be complete before cutover:**
- `define-v2-foundation` - v2 infrastructure scaffolded
- `add-go-api` - Go API server complete
- `add-svelte-admin` - Admin UI complete and tested
- `add-svelte-public` - Public site complete and tested
- `add-image-processing` - Image migration complete
- `add-articles-system` - Article rendering working

## Success Criteria

1. gallformers.org resolves to Fly.io app
2. All public pages render correctly (spot check + automated verification)
3. Admin login works with Auth0
4. Image display works (S3 integration)
5. Database contains all production data
6. v1 code removed from repository
7. DO Droplet cancelled (cost savings: ~$25/month)
8. Rollback procedure tested and documented
