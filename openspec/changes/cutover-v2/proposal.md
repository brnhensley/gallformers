# Change: Cutover from V1 to V2

## Status

**Repository restructure: COMPLETE** - V2 Phoenix code promoted to root, V1 archived in `v1/`.

**Remaining work**: DNS cutover and DO Droplet decommissioning.

## Why

After completing the Phoenix/LiveView rewrite, the new V2 stack running on Fly.io needs to replace the V1 Next.js stack running on Digital Ocean. This cutover must be executed carefully to:

- Minimize downtime (target: <10 minutes, acceptable: <30 minutes)
- Ensure zero data loss
- Preserve all public URLs (SEO critical)
- Provide rollback capability if issues discovered

## What Changes

### Cutover Scope

| Action | Status | Description |
|--------|--------|-------------|
| Code restructure | ✅ DONE | V2 promoted to root, V1 archived in `v1/` |
| Database sync | Pending | Final sync of SQLite from DO volume to Fly.io volume |
| DNS switch | Pending | Update Namecheap DNS to point gallformers.org/com to Fly.io |
| Verification | Pending | Validate all critical paths work correctly |
| Rollback prep | Pending | Document and test rollback procedure |
| Deprecation | Pending | Delete v1/ directory, cancel DO Droplet |

### What Moves

- **gallformers.org** DNS: DO Droplet IP → Fly.io app
- **gallformers.com** DNS: DO Droplet IP → Fly.io app
- **Database**: DO mounted volume → Fly.io persistent volume

### What Stays

- **S3 images**: Continue using same bucket/paths
- **Auth0**: Same tenant, updated callback URLs

### **BREAKING** Changes

- None for end users (URLs preserved)
- v1 codebase archived then deleted from repository
- DO infrastructure decommissioned

## Impact

- **Affected specs**: `v2-infrastructure` (adds cutover requirements)
- **Affected code**: Repository structure (v1 removal complete, cleanup pending)
- **Risk**: Medium - mitigated by rollback procedure and staged approach

## Dependencies

**Must be complete before cutover:**
- ✅ Phoenix/LiveView application deployed to Fly.io
- ✅ V2 code promoted to repository root
- ✅ V1 code archived in `v1/` subdirectory
- Pending: Final verification of all V2 functionality

## Success Criteria

1. gallformers.org resolves to Fly.io app
2. All public pages render correctly (spot check + automated verification)
3. Admin login works with Auth0
4. Image display works (S3 integration)
5. Database contains all production data
6. v1/ directory removed from repository
7. DO Droplet cancelled (cost savings: ~$25/month)
8. Rollback procedure tested and documented
