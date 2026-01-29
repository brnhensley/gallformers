# Admin Dashboard: V1 vs V2 Comparison

## Overview

| Attribute | V1 | V2 |
|-----------|----|----|
| **Route** | `/admin` | `/admin` |
| **File** | `v1/pages/admin/index.tsx` | `lib/gallformers_web/live/admin/dashboard_live.ex` |
| **Framework** | Next.js (React) | Phoenix LiveView |
| **Auth Component** | `v1/components/auth.tsx` | `Gallformers.Accounts` context |
| **Layout** | Inline with `<Auth>` wrapper | `Layouts.admin` component |

---

## UI Layer Comparison

### Navigation Links

| Feature | V1 | V2 | Status | Notes |
|---------|----|----|--------|-------|
| Dashboard link | N/A (you're already here) | `/admin` (sidebar) | Enhanced | V2 has persistent sidebar navigation |
| Taxonomy | `/admin/taxonomy` | `/admin/taxonomy` | Matched | |
| Sections | `/admin/section` | N/A | V1-only | Merged into Taxonomy in V2 |
| Hosts | `/admin/host` | `/admin/hosts` | Matched | Route changed to plural |
| Galls | `/admin/gall` | `/admin/galls` | Matched | Route changed to plural |
| Images | `/admin/images` | `/admin/images` | Matched | |
| Gall-Host Mappings | `/admin/gallhost` | `/admin/gallhost` | Matched | |
| Sources | `/admin/source` | `/admin/sources` | Matched | Route changed to plural |
| Species-Source Mappings | `/admin/speciessource` | `/admin/species-sources/add`, `/admin/species-sources/find` | Enhanced | Split into two specialized views |
| Glossary | `/admin/glossary` | `/admin/glossary` | Matched | |
| Browse Galls | `/admin/browse/galls` | N/A (merged into `/admin/galls`) | Merged | Index page now has browse functionality |
| Browse Hosts | `/admin/browse/hosts` | N/A (merged into `/admin/hosts`) | Merged | Index page now has browse functionality |
| Browse Sources | `/admin/browse/sources` | N/A (merged into `/admin/sources`) | Merged | Index page now has browse functionality |

### Super Admin Links

| Feature | V1 | V2 | Status | Notes |
|---------|----|----|--------|-------|
| Filter Terms | `/admin/filterterms` | `/admin/filter-terms` | Matched | Route changed to kebab-case |
| Places | `/admin/place` | `/admin/places` | Matched | Route changed to plural |
| User Management | N/A | `/admin/users` | V2-only | New feature |

### New V2 Features (Not in V1)

| Feature | Route | Description |
|---------|-------|-------------|
| Dashboard Statistics | `/admin` | Shows counts for galls, hosts, sources, images |
| Quick Actions | `/admin` | Card-based links to common tasks |
| Add Undescribed Gall | `/admin/galls/undescribed` | Specialized form for undescribed galls |
| Image Audit | `/admin/image-audit` | Check for orphan images and attribution issues |
| Articles Admin | `/admin/articles` | Manage reference articles |
| User Profile | `/admin/profile` | View/edit own profile |
| Bulk Species-Source | `/admin/species-sources/add` | Add species descriptions from sources in bulk |
| Quick Find Species-Source | `/admin/species-sources/find` | Search and edit species-source mappings |

### Visual Design

| Aspect | V1 | V2 | Status |
|--------|----|----|--------|
| Layout | Simple vertical list | Grid-based cards with statistics | Enhanced |
| Navigation | ListGroup items inline | Sidebar navigation + action cards | Enhanced |
| Icons | None | Phosphor icons throughout | Enhanced |
| Responsive | Bootstrap columns | Tailwind grid with mobile sidebar | Enhanced |
| Statistics display | None | Stat cards with counts | V2-only |
| Welcome message | None | Welcome box with Discord link | V2-only |
| Migration notice | None | Red notice about ongoing migration | V2-only |

---

## Business Logic Comparison

### Authentication

| Aspect | V1 | V2 |
|--------|----|----|
| **Auth wrapper** | `<Auth>` component (`v1/components/auth.tsx:6-35`) | `:admin` pipeline in router |
| **Session management** | `next-auth/react` `useSession()` hook | Phoenix session via `:fetch_current_user` on_mount |
| **Unauthenticated handling** | Shows login prompt with `signIn()` button | Redirects to `/auth/login` via pipeline |
| **Loading state** | "Hold tight. Working on vetting you..." text | Handled by LiveView mounting |

### Super Admin Check

**V1** (`v1/components/auth.tsx:4`):
```typescript
export const superAdmins = ['jeff', 'adamjameskranz'];
// Line 26: checks session.user.name in superAdmins array
```

**V2** (`lib/gallformers/accounts.ex:126-129`):
```elixir
def superadmin?(nil), do: false
def superadmin?(%Auth0User{} = user), do: Auth0User.superadmin?(user)
def superadmin?(%{roles: roles}) when is_list(roles), do: "superadmin" in roles
def superadmin?(_), do: false
```

| Aspect | V1 | V2 | Status |
|--------|----|----|--------|
| Superadmin detection | Hardcoded username list | Role-based from Auth0 | Enhanced |
| Location | Client-side component | Server-side context function | Improved security |
| Flexibility | Must redeploy to change | Managed via Auth0 dashboard | Enhanced |

### Statistics Computation

**V1**: None - dashboard is navigation-only

**V2** (`lib/gallformers_web/live/admin/dashboard_live.ex:148-156`):
```elixir
defp assign_stats(socket) do
  stats = %{
    gall_count: Species.count_galls(),
    host_count: Hosts.count_hosts(),
    source_count: Sources.count_sources(),
    image_count: Images.count_images()
  }
  assign(socket, :stats, stats)
end
```

| Statistic | V1 | V2 Query Location | Status |
|-----------|----|--------------------|--------|
| Gall count | N/A | `lib/gallformers/species.ex:131-136` | V2-only |
| Host count | N/A | `lib/gallformers/hosts.ex:56-61` | V2-only |
| Source count | N/A | `lib/gallformers/sources.ex:42-46` | V2-only |
| Image count | N/A | `lib/gallformers/images.ex:420-422` | V2-only |

---

## Data Layer Comparison

### Database Queries

**V1**: No queries - pure navigation page

**V2**: Statistics queries on mount

| Query | Location | SQL |
|-------|----------|-----|
| Gall count | `Species.count_galls/0` | `SELECT COUNT(id) FROM species WHERE taxoncode = 'gall'` |
| Host count | `Hosts.count_hosts/0` | `SELECT COUNT(id) FROM species WHERE taxoncode = 'plant'` |
| Source count | `Sources.count_sources/0` | `SELECT COUNT(id) FROM source` |
| Image count | `Images.count_images/0` | `SELECT COUNT(id) FROM image` |

### Performance Considerations

| Aspect | V1 | V2 |
|--------|----|----|
| Initial load queries | 0 | 4 (stats) |
| Server-side rendering | Yes (SSR) | Yes (LiveView) |
| Real-time updates | No | Possible (not implemented) |
| Caching | N/A | Not implemented for stats |

---

## File Structure Summary

### V1 Files

| File | Lines | Purpose |
|------|-------|---------|
| `v1/pages/admin/index.tsx` | 1-98 | Main dashboard page |
| `v1/components/auth.tsx` | 1-37 | Auth wrapper with superAdmin check |

### V2 Files

| File | Lines | Purpose |
|------|-------|---------|
| `lib/gallformers_web/live/admin/dashboard_live.ex` | 1-158 | Dashboard LiveView |
| `lib/gallformers_web/components/layouts.ex` | 456-555+ | Admin layout with sidebar |
| `lib/gallformers/accounts.ex` | 126-129 | `superadmin?/1` function |
| `lib/gallformers/accounts/auth0_user.ex` | 61-63 | User-level superadmin check |
| `lib/gallformers/species.ex` | 131-136 | `count_galls/0` |
| `lib/gallformers/hosts.ex` | 56-61 | `count_hosts/0` |
| `lib/gallformers/sources.ex` | 42-46 | `count_sources/0` |
| `lib/gallformers/images.ex` | 420-422 | `count_images/0` |
| `lib/gallformers_web/helpers.ex` | 23-31 | `format_number/1` helper |

---

## Comparison Summary

| Aspect | V1 | V2 | Status | Notes |
|--------|----|----|--------|-------|
| **Navigation** | Simple list | Sidebar + action cards | Enhanced | Persistent nav in V2 |
| **Statistics** | None | 4 counts displayed | V2-only | Galls, hosts, sources, images |
| **Auth mechanism** | Client-side wrapper | Server-side pipeline | Enhanced | Better security |
| **Superadmin check** | Hardcoded usernames | Auth0 role-based | Enhanced | More flexible |
| **Sections admin link** | Present | Removed | Removed | Merged into Taxonomy |
| **Browse pages links** | 3 separate pages | Merged into index pages | Merged | Cleaner navigation |
| **Quick actions** | None | 11 action cards | V2-only | Common tasks prominent |
| **Mobile support** | Bootstrap responsive | Tailwind with mobile menu | Enhanced | Dedicated mobile sidebar |
| **Help resources** | GitHub + Slack links | Discord link | Changed | Simplified |
| **Visual design** | Bootstrap ListGroup | Tailwind cards with icons | Redesigned | Modern look |
| **User management** | None | `/admin/users` link | V2-only | Superadmin feature |
| **Profile link** | None | `/admin/profile` | V2-only | User self-service |
| **Articles admin** | None | `/admin/articles` link | V2-only | New content type |
| **Image audit** | None | `/admin/image-audit` link | V2-only | Quality assurance |

---

## Recommendations

### Functional Parity

1. **Complete** - All V1 navigation links have equivalents (Sections merged into Taxonomy per design decision)
2. **Enhanced** - V2 adds statistics, quick actions, and new admin features

### Potential Improvements

1. **Stats caching** - Consider caching statistics to reduce DB queries on each dashboard load
2. **Real-time stats** - Could use PubSub to update stats when records are created/deleted
3. **Recent activity** - V2 could show recent edits/additions (not in V1 either)
4. **Help documentation** - Both versions point to external resources; could inline more help

### Migration Notes

- V1 users accustomed to the simple list may need orientation to the new card-based layout
- The Sections admin being merged into Taxonomy should be communicated to users
- New features (Image Audit, Articles, User Management) should be introduced to admins
