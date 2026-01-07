# Change: Fix Critical Security Vulnerabilities

## Why

The January 2026 technical audit identified **critical security vulnerabilities** that must be fixed immediately, regardless of the planned rewrite. These issues could allow:

1. **Unauthorized access** to all protected admin endpoints
2. **SQL injection** attacks through multiple database operations
3. **Credential exposure** if `.env.local` was ever committed to git history

## What Changes

### 1. Auth Bypass Fix

**File**: `libs/api/apipage.ts`

**Issue**: Missing `return` after `res.status(401).end()` at lines 27 and 68. The function continues executing even for unauthenticated requests.

```typescript
// CURRENT (VULNERABLE)
if (!session) {
    res.status(401).end();
}
// Code continues executing...

// FIXED
if (!session) {
    res.status(401).end();
    return;  // <-- Add this
}
```

**Affected functions**:
- `apiIdEndpoint` (line 26-28)
- `apiUpsertEndpoint` (line 66-69)

### 2. SQL Injection Fixes

**Issue**: String interpolation in raw SQL queries using `Prisma.sql([sql])` pattern.

**Vulnerable files and locations**:

| File | Line | Query Type | Risk |
|------|------|-----------|------|
| `libs/db/gall.ts` | 745 | DELETE species | ID injection |
| `libs/db/source.ts` | 125 | DELETE source | ID injection |
| `libs/db/taxonomy.ts` | 548, 640, 702-703 | DELETE taxonomy/species | ID injection |
| `libs/db/gallhost.ts` | 13, 19, 27, 31 | INSERT/DELETE host | ID injection |
| `libs/db/place.ts` | 113 | DELETE place | ID injection |
| `libs/db/species.ts` | 14, 18 | UPDATE species | **String injection** (abundance) |

**Fix pattern**:
```typescript
// CURRENT (VULNERABLE)
const sql = `DELETE FROM source WHERE id = ${id}`;
db.$executeRaw(Prisma.sql([sql]));

// FIXED (parameterized)
db.$executeRaw`DELETE FROM source WHERE id = ${id}`;
// OR
db.$executeRaw(Prisma.sql`DELETE FROM source WHERE id = ${id}`);
```

**Highest risk**: `species.ts:18` injects a string directly:
```typescript
// VULNERABLE - string injection
SET abundance_id = (SELECT id FROM abundance WHERE abundance = '${abundance}')
```

### 3. Credential Verification

**Issue**: The audit flagged credentials potentially in git history.

**Status**: Likely NOT an issue - `.env.local` appears to have never been committed (no git history found), and `.gitignore` already includes `.env`, `.env.local`, and `prisma/.env`.

**Actions**:
1. Verify `.env.local` was never committed: `git log --all --full-history -- ".env.local"`
2. If found (unlikely), rotate credentials and use `git filter-repo` to purge

## Impact

- **Affected specs**: None (security fix, no behavior change)
- **Affected code**:
  - `libs/api/apipage.ts`
  - `libs/db/gall.ts`
  - `libs/db/source.ts`
  - `libs/db/taxonomy.ts`
  - `libs/db/gallhost.ts`
  - `libs/db/place.ts`
  - `libs/db/species.ts`
- **Risk**: LOW - these are targeted fixes that don't change business logic
- **Testing**: Existing functionality should work identically

## Priority

**CRITICAL** - Deploy as soon as possible. This blocks no other work and should be completed before any feature development.
