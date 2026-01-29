# V1 to V2 Page Mappings

This document tracks the mapping between V1 (Next.js) pages and V2 (Phoenix LiveView) equivalents.

## Public Pages

| V1 Page | V2 Equivalent | Status | Reviewed |
|---------|---------------|--------|----------|
| [Home](home-V1.md) (`/`) | [Home](home-V2.md) (`/`) | Matched | [x] |
| [About](about-V1.md) (`/about`) | [About](about-V2.md) (`/about`) | Matched | [x] |
| [ID Tool](id-V1.md) (`/id`) | [ID Tool](id-V2.md) (`/id`) | Matched | [x] |
| [Explore](explore-V1.md) (`/explore`) | [Explore](explore-V2.md) (`/explore`) | Matched | [x] |
| [Glossary](glossary-V1.md) (`/glossary`) | [Glossary](glossary-V2.md) (`/glossary`) | Matched | [x] |
| [Global Search](globalsearch-V1.md) (`/globalsearch`) | [Global Search](globalsearch-V2.md) (`/globalsearch`) | Matched | [x] |
| [Reference Index](refindex-V1.md) (`/refindex`) | [Reference Index](refindex-V2.md) (`/refindex`) | Matched | [x] |
| [Filter Guide](filterguide-V1.md) (`/filterguide`) | [Filter Guide](filterguide-V2.md) (`/filterguide`) | Matched | [x] |
| [Resources](resources-V1.md) (`/resources`) | [Resources](resources-V2.md) (`/resources`) | Matched | [x] |
| [404 Page](404-V1.md) | Phoenix custom error handling | Matched | [x] |

## Entity Detail Pages

| V1 Page | V2 Equivalent | Status | Reviewed |
|---------|---------------|--------|----------|
| [Gall Detail](gall-V1.md) (`/gall/[id]`) | [Gall Detail](gall-V2.md) (`/gall/:id`) | Matched | [x] |
| [Host Detail](host-V1.md) (`/host/[id]`) | [Host Detail](host-V2.md) (`/host/:id`) | Matched | [x] |
| [Family Detail](family-V1.md) (`/family/[id]`) | [Family Detail](family-V2.md) (`/family/:id`) | Matched | [x] |
| [Genus Detail](genus-V1.md) (`/genus/[id]`) | [Genus Detail](genus-V2.md) (`/genus/:id`) | Matched | [x] |
| [Section Detail](section-V1.md) (`/section/[id]`) | [Section Detail](section-V2.md) (`/section/:id`) | Matched | [x] |
| [Source Detail](source-V1.md) (`/source/[id]`) | [Source Detail](source-V2.md) (`/source/:id`) | Matched | [x] |
| [Place Detail](place-V1.md) (`/place/[id]`) | [Place Detail](place-V2.md) (`/place/:id`) | Matched | [x] |
| [Reference Article](ref-article-V1.md) (`/ref/[slug]`) | [Reference Article](ref-article-V2.md) (`/ref/:slug`) | Matched | [x] |

## Admin Pages

| V1 Page | V2 Equivalent | Status | Reviewed |
|---------|---------------|--------|----------|
| [Admin Dashboard](admin-dashboard-V1.md) (`/admin`) | [Admin Dashboard](admin-dashboard-V2.md) (`/admin`) | Matched | [x] |
| [Taxonomy Admin](admin-taxonomy-V1.md) (`/admin/taxonomy`) | [Taxonomy Admin](admin-taxonomy-V2.md) (`/admin/taxonomy`) | Matched | [x] |
| [Section Admin](admin-section-V1.md) (`/admin/section`) | N/A (merged into Taxonomy) | Unmatched | [x] |
| [Host Admin](admin-host-V1.md) (`/admin/host`) | [Host Admin](admin-host-V2.md) (`/admin/hosts`) | Matched | [x] |
| [Gall Admin](admin-gall-V1.md) (`/admin/gall`) | [Gall Admin](admin-gall-V2.md) (`/admin/galls`) | Matched | [x] |
| [Images Admin](admin-images-V1.md) (`/admin/images`) | [Images Admin](admin-images-V2.md) (`/admin/images`) | Matched | [x] |
| [Gall-Host Admin](admin-gallhost-V1.md) (`/admin/gallhost`) | [Gall-Host Admin](admin-gallhost-V2.md) (`/admin/gallhost`) | Matched | [x] |
| [Source Admin](admin-source-V1.md) (`/admin/source`) | [Source Admin](admin-source-V2.md) (`/admin/sources`) | Matched | [x] |
| [Species-Source Admin](admin-speciessource-V1.md) (`/admin/speciessource`) | [Species-Source Admin](admin-speciessource-V2.md) (`/admin/species-sources`) | Matched | [x] |
| [Glossary Admin](admin-glossary-V1.md) (`/admin/glossary`) | [Glossary Admin](admin-glossary-V2.md) (`/admin/glossary`) | Matched | [x] |
| [Filter Terms Admin](admin-filterterms-V1.md) (`/admin/filterterms`) | [Filter Terms Admin](admin-filterterms-V2.md) (`/admin/filter-terms`) | Matched | [x] |
| [Place Admin](admin-place-V1.md) (`/admin/place`) | [Place Admin](admin-place-V2.md) (`/admin/places`) | Matched | [x] |

## Admin Browse Pages

| V1 Page | V2 Equivalent | Status | Reviewed |
|---------|---------------|--------|----------|
| [Browse Galls](admin-browse-galls-V1.md) (`/admin/browse/galls`) | Merged into `/admin/galls` | Matched | [x] |
| [Browse Hosts](admin-browse-hosts-V1.md) (`/admin/browse/hosts`) | Merged into `/admin/hosts` | Matched | [x] |
| [Browse Sources](admin-browse-sources-V1.md) (`/admin/browse/sources`) | Merged into `/admin/sources` | Matched | [x] |

## V2-Only Pages (New)

| V2 Page | Description | Reviewed |
|---------|-------------|----------|
| [User Profile](user-profile-V2.md) (`/user/:nickname`) | Public user profile page | [x] |
| [Admin Profile](admin-profile-V2.md) (`/admin/profile`) | Admin user's own profile | [x] |
| [Image Audit](admin-image-audit-V2.md) (`/admin/image-audit`) | Image integrity auditing | [x] |
| [Articles Admin](admin-articles-V2.md) (`/admin/articles`) | Reference article management | [x] |
| [Users Admin](admin-users-V2.md) (`/admin/users`) | User management (superadmin) | [x] |
| [Undescribed Galls](admin-undescribed-V2.md) (`/admin/galls/undescribed`) | Undescribed galls management | [x] |

## Summary

- **Total V1 Pages**: 25
- **Matched in V2**: 23
- **Unmatched (V1 only)**: 1 (Section Admin - merged into Taxonomy)
- **V2-Only Pages**: 6
