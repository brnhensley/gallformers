---
status: active
created: 2026-03-18
updated: 2026-03-18
epic: platform
docs: [docs/testing-philosophy.md]
relates: [2648]
---

# Test suite alignment to testing philosophy

## Tracking

Two lists: **Done** and **Remaining**. A test file that appears in neither list has not been evaluated — this catches new files created by agents.

### Done — meets testing philosophy

- test/gallformers/gall_hosts_test.exs — 36 unit tests, owns data, strong assertions
- test/gallformers_web/live/admin/gall_host_live_test.exs — 49 tests, owns data, DB verification after save, integration workflow

### Remaining — not yet evaluated

#### Tier 1: Unit — Context (existing)

- test/gallformers/accounts_test.exs
- test/gallformers/analytics_test.exs
- test/gallformers/articles_test.exs
- test/gallformers/changeset_helpers_test.exs
- test/gallformers/content_images_test.exs
- test/gallformers/galls_identification_test.exs
- test/gallformers/galls_test.exs
- test/gallformers/glossaries_test.exs
- test/gallformers/hosts_test.exs
- test/gallformers/images_test.exs
- test/gallformers/inaturalist_test.exs
- test/gallformers/keys_test.exs
- test/gallformers/markdown_test.exs
- test/gallformers/places_test.exs
- test/gallformers/plants_test.exs
- test/gallformers/ranges_test.exs
- test/gallformers/request_logger_test.exs
- test/gallformers/search_test.exs
- test/gallformers/site_settings_test.exs
- test/gallformers/species_test.exs
- test/gallformers/storage_test.exs

#### Tier 1: Unit — Context (need to write)

- Sources — 2 tests, needs ~15 more
- FilterFields — 0 tests
- SchemaFields — 0 tests

#### Tier 1: Unit — Components

- test/gallformers_web/components/data_display_components_test.exs
- test/gallformers_web/components/form_components_test.exs
- test/gallformers_web/components/layouts_test.exs
- test/gallformers_web/components/region_scope_test.exs
- test/gallformers_web/components/tree_components_test.exs
- Missing: typeahead, multi_select_typeahead, taxon_name, selectable_tree

#### Tier 1: Unit — JS hooks

- range_map.js — 0 tests, need framework + tests
- typeahead hook — 0 tests
- IndeterminateCheckbox hook — 0 tests
- Other hooks — inventory needed

#### Tier 2: Integration — Admin LiveViews

- test/gallformers_web/live/admin/host_live/form_test.exs
- test/gallformers_web/live/admin/host_live/wcvp_test.exs
- test/gallformers_web/live/admin/host_range_live_test.exs
- test/gallformers_web/live/admin/gall_range_live_test.exs
- test/gallformers_web/live/admin/dashboard_live_test.exs
- test/gallformers_web/live/admin/users_live_test.exs
- test/gallformers_web/live/admin/profile_live_test.exs
- test/gallformers_web/live/admin/ops_live_test.exs
- test/gallformers_web/live/admin/section_live_test.exs
- test/gallformers_web/live/admin/country_drill_down_test.exs
- test/gallformers_web/live/admin/powo_diff_review_test.exs
- test/gallformers_web/live/admin/content_image_manager_test.exs
- test/gallformers_web/live/admin/inat_import_component_test.exs
- test/gallformers_web/live/admin/taxonomy_form_test.exs
- test/gallformers_web/live/admin/deferred_changes_test.exs

#### Tier 2: Integration — Public LiveViews

- test/gallformers_web/live/search_live_test.exs
- test/gallformers_web/live/home_live_test.exs
- test/gallformers_web/live/gall_live_test.exs
- test/gallformers_web/live/family_live_test.exs
- test/gallformers_web/live/place_live_test.exs
- test/gallformers_web/live/places_live_test.exs
- test/gallformers_web/integration_test.exs

#### Tier 2: Integration — Controllers/API

- test/gallformers_web/controllers/ (all files)

#### Tier 2: Integration — Plugs

- test/gallformers_web/plugs/ (all files)

#### Tier 2: Integration — Not yet implemented

- Data invariants on test DB (port from prod_data/invariants_test.exs)
- LiveView↔JS hook contract tests

#### Tier 3: E2E browser tests

- ID Tool flow
- Gall detail page
- Admin: create/edit gall workflow
- Admin: edit host workflow
- Search → detail flow
- Existing smoke tests — evaluate

#### Tier 5: Post-deploy smoke tests

- Evaluate current tests against philosophy

#### Structural issues

- JS test framework selection and setup (matter 2648)

