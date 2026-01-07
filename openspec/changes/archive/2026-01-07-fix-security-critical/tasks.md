# Tasks: Fix Critical Security Vulnerabilities

## 1. Auth Bypass Fix

- [x] 1.1 Add `return` after `res.status(401).end()` in `apiIdEndpoint` (`libs/api/apipage.ts:27`)
- [x] 1.2 Add `return` after `res.status(401).end()` in `apiUpsertEndpoint` (`libs/api/apipage.ts:68`)
- [x] 1.3 Test that protected endpoints return 401 for unauthenticated requests

## 2. SQL Injection Fixes

- [x] 2.1 Fix `libs/db/gall.ts:745` - parameterize DELETE species query
- [x] 2.2 Fix `libs/db/source.ts:125` - parameterize DELETE source query
- [x] 2.3 Fix `libs/db/taxonomy.ts:548` - parameterize DELETE taxonomy query
- [x] 2.4 Fix `libs/db/taxonomy.ts:638-640` - parameterize UPDATE query
- [x] 2.5 Fix `libs/db/taxonomy.ts:702-703` - parameterize DELETE queries
- [x] 2.6 Fix `libs/db/gallhost.ts:13` - parameterize INSERT host query
- [x] 2.7 Fix `libs/db/gallhost.ts:19` - parameterize DELETE host query
- [x] 2.8 Fix `libs/db/gallhost.ts:27` - parameterize DELETE speciesplace query
- [x] 2.9 Fix `libs/db/gallhost.ts:31` - parameterize INSERT speciesplace query
- [x] 2.10 Fix `libs/db/place.ts:113` - parameterize DELETE place query
- [x] 2.11 Fix `libs/db/species.ts:14` - parameterize UPDATE species query
- [x] 2.12 Fix `libs/db/species.ts:18` - parameterize UPDATE species query (string injection)
- [x] 2.13 Run `yarn lint` and `yarn check-types` to verify no regressions

## 3. Credential Verification

- [x] 3.1 Verify `.env.local` never committed: `git log --all --full-history -- ".env.local"` - **CONFIRMED: Never committed**
- [x] 3.2 Check historical .env files - **CONFIRMED: Only contained API_URL, no secrets**
- [x] 3.3 Confirm `.gitignore` includes all sensitive files - **CONFIRMED: `.env`, `.env.local`, `prisma/.env` all listed**

## 4. Deployment

- [x] 4.1 Test all admin CRUD operations locally
- [x] 4.2 Deploy to production
- [x] 4.3 Verify admin functionality in production
