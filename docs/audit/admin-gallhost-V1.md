# Admin Gall-Host Page Comparison: V1 vs V2

## Overview

| Attribute | V1 | V2 |
|-----------|-----|-----|
| **Route** | `/admin/gallhost` | `/admin/gallhost` |
| **Main File** | `v1/pages/admin/gallhost.tsx` | `lib/gallformers_web/live/admin/gall_host_live.ex` |
| **Framework** | Next.js + React | Phoenix LiveView |
| **State Management** | React useState + useAdmin hook | Socket assigns + DeferredChanges |
| **Map Library** | react-simple-maps | D3.js (via RangeMap hook) |

---

## 1. UI Layer Comparison

### Gall Selection

| Aspect | V1 | V2 | Status | Notes |
|--------|-----|-----|--------|-------|
| Search input | AsyncTypeahead (react-bootstrap-typeahead) | `.typeahead` component | Complete | V2 uses reusable component |
| Search endpoint | `/api/gall?q={query}` | LiveView `search_galls` event | Complete | V2 searches with `Species.search_species_by_name/3` |
| Pre-selection via URL | `?id={gall_id}` query param | `?id={gall_id}` query param | Complete | Both support deep linking |
| Clear selection | Typeahead clearButton | `.typeahead` clear_event | Complete | Same UX |

**V1 Implementation** (`v1/pages/admin/gallhost.tsx:186-191`):
```tsx
Gall:
{adminForm.mainField('name', { searchEndpoint: (s) => `../api/gall?q=${s}` })}
```

**V2 Implementation** (`lib/gallformers_web/live/admin/gall_host_live.ex:464-479`):
```elixir
<.typeahead
  id="gall-picker"
  label="Gall:"
  placeholder="Search for a gall..."
  query={@gall_search_query}
  results={@gall_search_results}
  selected={@selected_gall}
  search_event="search_galls"
  select_event="select_gall"
  clear_event="clear_gall"
  display_fn={& &1.name}
/>
```

### Host Multi-Select

| Aspect | V1 | V2 | Status | Notes |
|--------|-----|-----|--------|-------|
| Component | Typeahead (multiple=true) | `.multi_select_dropdown` | Complete | Both support multi-select with chips |
| Search endpoint | Preloaded `hosts` prop (all hosts) | LiveView `search_hosts` event | Different | V2 searches on-demand; V1 preloads all |
| Validation | react-hook-form validate | Manual check (`@hosts == []`) | Complete | Both require at least one host |
| Add/remove UX | Typeahead onChange | Separate add/remove events | Complete | Same visual result |

**V1 Implementation** (`v1/pages/admin/gallhost.tsx:200-227`):
```tsx
<Controller
  control={adminForm.form.control}
  name="hosts"
  render={() => (
    <Typeahead
      id="hosts"
      options={hosts}
      labelKey="name"
      multiple
      clearButton
      disabled={!selected}
      selected={gallHosts ? gallHosts : []}
      onChange={(s: SpeciesWithPlaces[]) => setGallHosts([...s])}
    />
  )}
/>
```

**V2 Implementation** (`lib/gallformers_web/live/admin/gall_host_live.ex:489-512`):
```elixir
<.multi_select_dropdown
  id="host-picker"
  label="Hosts:"
  type={:hosts}
  search_results={@host_search_results}
  selected={@hosts}
  search_query={@host_search_query}
  item_id={:host_relation_id}
  on_search="search_hosts"
  on_add="add_host"
  on_remove="remove_host"
  required={true}
/>
```

### Interactive Map (Range Exclusions)

| Aspect | V1 | V2 | Status | Notes |
|--------|-----|-----|--------|-------|
| Library | react-simple-maps (ComposableMap) | D3.js via RangeMap hook | Complete | Both render US/Canada choropleth |
| Projection | geoConicEqualArea (custom config) | geoConicEqualArea (matching config) | Complete | Same projection params |
| Topology file | `/usa-can-topo.json` | `/data/usa-can-topo.json` | Complete | Same data, different path |
| Colors (in range) | ForestGreen (#228B22) | ForestGreen (#228B22) | Complete | Identical |
| Colors (excluded) | LightCoral | LightCoral (#F08080) | Complete | Identical |
| Colors (neither) | White | White (#FFFFFF) | Complete | Identical |
| Click to toggle | Yes (onClick handler) | Yes (`toggle_region` event) | Complete | Same behavior |
| Tooltip | react-tooltip | Custom CSS tooltip | Complete | V2 built-in to hook |
| Zoom/Pan | ZoomableGroup | D3 zoom behavior in modal | Enhanced | V2 has modal with zoom controls |
| Select All/Deselect All | Buttons | Buttons | Complete | Same functionality |

**V1 Map Implementation** (`v1/pages/admin/gallhost.tsx:286-338`):
```tsx
<ComposableMap projection="geoConicEqualArea" projectionConfig={projConfig}>
  <ZoomableGroup zoom={1} minZoom={0.75}>
    <Geographies geography="../usa-can-topo.json">
      {({ geographies }) =>
        geographies.map((geo) => (
          <Geography
            key={geo.rsmKey}
            geography={geo}
            fill={outRange.has(code) ? 'LightCoral' : inRange.has(code) ? 'ForestGreen' : 'White'}
            onClick={() => { /* toggle logic */ }}
          />
        ))
      }
    </Geographies>
  </ZoomableGroup>
</ComposableMap>
```

**V2 Map Implementation** (`lib/gallformers_web/live/admin/gall_host_live.ex:589-603` + `assets/js/hooks/range_map.js`):
```elixir
<div
  id="gallhost-range-map"
  phx-hook="RangeMap"
  phx-update="ignore"
  data-in-range={Jason.encode!(@in_range)}
  data-excluded-range={Jason.encode!(@excluded_places)}
  data-editable="true"
/>
```

### Legend and Actions

| Aspect | V1 | V2 | Status | Notes |
|--------|-----|-----|--------|-------|
| Legend colors | Row/Col layout | Flex layout | Complete | Same visual content |
| Select All button | Button (outline-secondary) | Button (gray border) | Complete | Same functionality |
| Deselect All button | Button (outline-secondary) | Button (gray border) | Complete | Same functionality |
| InfoTip | InfoTip component | `.icon` with title attr | Complete | Same help text |

### Navigation Links

| Aspect | V1 | V2 | Status | Notes |
|--------|-----|-----|--------|-------|
| Link to add host | `<Link href="./host">` | `<.link navigate={~p"/admin/hosts"}>` | Complete | Same purpose |
| View public page | Not present | `<.link navigate={~p"/gall/{id}"}>` | Enhanced | V2 adds quick link |
| Edit gall details | Not present | `<.link navigate={~p"/admin/galls/{id}"}>` | Enhanced | V2 adds quick link |

---

## 2. Business Logic Comparison

### State Management

| Aspect | V1 | V2 | Status | Notes |
|--------|-----|-----|--------|-------|
| Gall selection | useState + useAdmin hook | Socket assign `:selected_gall` | Complete | Different paradigms |
| Host list (pending) | useState `gallHosts` | DeferredChanges `:hosts` | Complete | V2 has dedicated abstraction |
| Range exclusions | useState `inRange`, `outRange` | Socket assigns `:excluded_place_ids`, `:in_range`, `:excluded_places` | Complete | V2 tracks IDs and codes separately |
| Dirty tracking | react-hook-form `isDirty` | FormHelpers `form_dirty` | Complete | Both track unsaved changes |

**V1 State** (`v1/pages/admin/gallhost.tsx:70-73`):
```tsx
const [gallHosts, setGallHosts] = useState<Array<SpeciesWithPlaces>>([]);
const [inRange, setInRange] = useState<Map<string, PlaceNoTreeApi>>(new Map());
const [outRange, setOutRange] = useState<Map<string, PlaceNoTreeApi>>(new Map());
```

**V2 State** (`lib/gallformers_web/live/admin/gall_host_live.ex:26-51`):
```elixir
socket
|> assign(:selected_gall, nil)
|> assign(DeferredChanges.init(:hosts, []))
|> assign(:host_places, [])
|> assign(:original_excluded_place_ids, [])
|> assign(:excluded_place_ids, [])
|> assign(:excluded_places, [])
|> assign(:in_range, [])
|> init_form_state()
```

### Validation

| Aspect | V1 | V2 | Status | Notes |
|--------|-----|-----|--------|-------|
| At least one host | react-hook-form validate | Template conditional render | Complete | V2 shows error inline |
| Gall selection required | Implicit (disabled state) | Conditional rendering + flash | Complete | Same protection |

**V1 Validation** (`v1/pages/admin/gallhost.tsx:213-214`):
```tsx
validate: (gh: GallHost[]) => {
  return gh.length > 0 || 'You must map at least one host to this gall.';
}
```

**V2 Validation** (`lib/gallformers_web/live/admin/gall_host_live.ex:512-514`):
```elixir
<p :if={@hosts == []} class="text-red-600 text-xs mt-1">
  You must map this gall to at least one host.
</p>
```

### Range Computation

| Aspect | V1 | V2 | Status | Notes |
|--------|-----|-----|--------|-------|
| Host places union | Client-side from `SpeciesWithPlaces.places` | Server-side `Hosts.get_places_for_host_species_ids/1` | Complete | V2 queries DB |
| Excluded place cleanup | useEffect when gallHosts changes | `recompute_host_places_and_range/1` | Complete | Both remove invalid exclusions |

**V1 Range Computation** (`v1/pages/admin/gallhost.tsx:139-164`):
```tsx
useEffect(() => {
  if (selected && gallHosts.length > 0) {
    const possibleRange = new Map<string, PlaceNoTreeApi>();
    gallHosts.flatMap((gh) => gh.places).forEach((p) => possibleRange.set(p.code, p));
    // ... handle exclusions
  }
}, [gallHosts, selected]);
```

**V2 Range Computation** (`lib/gallformers_web/live/admin/gall_host_live.ex:390-407`):
```elixir
defp recompute_host_places_and_range(socket) do
  hosts = socket.assigns.hosts
  host_species_ids = Enum.map(hosts, & &1.host_species_id)
  host_places = Hosts.get_places_for_host_species_ids(host_species_ids)
  # ... clean up exclusions
end
```

### Save Operation

| Aspect | V1 | V2 | Status | Notes |
|--------|-----|-----|--------|-------|
| Transaction | Prisma $transaction | Ecto Repo.transaction | Complete | Both wrap in transaction |
| Delete hosts | Raw SQL DELETE | `Species.remove_host_from_species/1` per relation | Complete | V2 iterates |
| Insert hosts | Batch INSERT | `Species.add_host_to_species/2` per host | Complete | V2 iterates |
| Set exclusions | Batch INSERT | `Hosts.set_range_exclusions_for_gall/2` | Complete | Same approach |

**V1 Save** (`v1/libs/db/gallhost.ts:16-39`):
```typescript
export const updateGallHosts = (gallhost: GallHostUpdateFields): TE.TaskEither<Error, GallApi> => {
  const doTx = () => () => {
    const deletes = db.$executeRaw`DELETE FROM host WHERE gall_species_id = ${gallhost.gall}`;
    const steps: PrismaPromise<number>[] = [deletes];
    if (hosts.length > 0) steps.push(toInsertStatement(gallhost.gall, hosts));
    steps.push(db.$executeRaw`DELETE FROM speciesplace WHERE species_id = ${gallhost.gall}`);
    // ... insert exclusions
    return db.$transaction(steps);
  };
  // ...
};
```

**V2 Save** (`lib/gallformers_web/live/admin/gall_host_live.ex:290-332`):
```elixir
def handle_event("save", _params, socket) do
  {hosts_to_add, hosts_to_remove} = DeferredChanges.compute_changes(socket, :hosts, ...)

  result = Repo.transaction(fn ->
    for relation_id <- hosts_to_remove do
      Species.remove_host_from_species(relation_id)
    end
    for host <- hosts_to_add do
      Species.add_host_to_species(gall.id, host.host_species_id)
    end
    Hosts.set_range_exclusions_for_gall(gall.id, socket.assigns.excluded_place_ids)
    :ok
  end)
  # ...
end
```

---

## 3. Data Layer Comparison

### Queries

| Query | V1 Location | V2 Location | Status |
|-------|-------------|-------------|--------|
| Get hosts for gall | `v1/libs/db/gallhost.ts:41-64` (`hostsByGallId`) | `lib/gallformers/hosts.ex:108-120` (`get_hosts_for_gall`) | Complete |
| Get host places | Included in `SpeciesWithPlaces` (preloaded) | `lib/gallformers/hosts.ex:182-193` (`get_places_for_gall`) | Complete |
| Get excluded places | Via `GallApi.excludedPlaces` | `lib/gallformers/hosts.ex:750-756` (`get_excluded_place_ids_for_gall`) | Complete |
| Search galls | `/api/gall?q={s}` | `Species.search_species_by_name/3` | Complete |
| Search hosts | Preloaded all hosts | `Species.search_species_by_name/3` | Different |

### Database Tables

| Table | V1 Usage | V2 Usage | Notes |
|-------|----------|----------|-------|
| `host` | Stores gall-host relations | Same | `gall_species_id`, `host_species_id` |
| `speciesplace` | Stores range exclusions (gall) | Same | When `species_id` is a gall, means "excluded from range" |
| `species` | For gall and host lookups | Same | `taxoncode` distinguishes gall vs plant |
| `place` | For place code/name lookups | Same | Geographic regions |

### API Endpoints

| Endpoint | V1 | V2 | Notes |
|----------|-----|-----|-------|
| Get hosts for gall | `/api/gallhost?gallid={id}` | N/A (LiveView) | V2 loads server-side |
| Save mappings | `/api/gallhost/insert` | N/A (LiveView) | V2 handles in `handle_event("save")` |
| Search galls | `/api/gall?q={s}` | N/A (LiveView) | V2 uses `search_species_by_name` |

---

## 4. Key Architectural Differences

### 1. Data Loading Strategy

**V1**: Preloads all hosts on page load via `getServerSideProps`, fetches gall hosts on-demand via API.
```typescript
// v1/pages/admin/gallhost.tsx:347-363
export const getServerSideProps: GetServerSideProps = async (context) => {
  return {
    props: {
      hosts: await mightFailWithArray<SimpleSpecies>()(allHostsWithPlaces()),
    },
  };
};
```

**V2**: Loads all places on mount, fetches hosts and gall data on-demand via LiveView events.
```elixir
# lib/gallformers_web/live/admin/gall_host_live.ex:26-28
def mount(_params, session, socket) do
  all_places = Places.list_places()
  # ...
end
```

### 2. Change Tracking

**V1**: Uses react-hook-form with manual state synchronization between `gallHosts` and form state.

**V2**: Uses `DeferredChanges` module for declarative change tracking with `init/2`, `add_pending/4`, `remove_pending/4`, and `compute_changes/3`.

### 3. Map Implementation

**V1**: React component with react-simple-maps wrapping react-tooltip.

**V2**: LiveView hook with D3.js, featuring:
- Thumbnail view with "click to expand"
- Modal with zoom controls (zoom in/out/reset)
- Pan and zoom via D3 behaviors
- Server-side range updates via `push_event`

### 4. Form State

**V1**: useAdmin hook provides unified form state with react-hook-form integration.

**V2**: FormHelpers behaviour provides dirty tracking, discard confirmation modal, and standard event handlers.

---

## 5. File Reference Table

| Purpose | V1 File | V2 File |
|---------|---------|---------|
| Main page | `v1/pages/admin/gallhost.tsx` | `lib/gallformers_web/live/admin/gall_host_live.ex` |
| Admin hook/helpers | `v1/hooks/useAdmin.tsx` | `lib/gallformers_web/live/admin/form_helpers.ex` |
| Change tracking | N/A (inline) | `lib/gallformers_web/live/admin/deferred_changes.ex` |
| DB queries (gall-host) | `v1/libs/db/gallhost.ts` | `lib/gallformers/hosts.ex` |
| API - get hosts | `v1/pages/api/gallhost/index.ts` | N/A (LiveView) |
| API - save mappings | `v1/pages/api/gallhost/insert.ts` | N/A (LiveView) |
| Species context | `v1/libs/db/gall.ts`, `v1/libs/db/host.ts` | `lib/gallformers/species.ex` |
| Map rendering | react-simple-maps (inline JSX) | `assets/js/hooks/range_map.js` |
| Topology data | `v1/public/usa-can-topo.json` | `priv/static/data/usa-can-topo.json` |
| Typeahead component | react-bootstrap-typeahead | `lib/gallformers_web/components/form_components.ex` |

---

## 6. Parity Status Summary

| Feature | Status | Notes |
|---------|--------|-------|
| Gall search/selection | Complete | Full parity |
| Host multi-select | Complete | V2 searches on-demand (more scalable) |
| Range map display | Complete | Same projection, colors, interactivity |
| Range exclusion toggle | Complete | Click to toggle works identically |
| Select All / Deselect All | Complete | Same functionality |
| Save with transaction | Complete | Both wrap in DB transaction |
| URL deep linking | Complete | `?id={gall_id}` works in both |
| Validation (one host) | Complete | Both enforce |
| Dirty state warning | Complete | V2 has discard confirmation modal |
| View public page link | Enhanced | V2 only |
| Edit gall details link | Enhanced | V2 only |
| Map zoom/pan | Enhanced | V2 has modal with zoom controls |

---

## 7. Recommendations

1. **No blocking issues** - V2 implementation has full feature parity with V1
2. **Performance improvement** - V2's on-demand host search scales better than V1's preload-all approach
3. **UX enhancement** - V2's map modal with zoom controls improves usability for dense regions
4. **Code quality** - V2's DeferredChanges module provides cleaner change tracking than V1's manual state management
5. **Consider adding** - Range summary (count of in-range/excluded places) is present in V2 but not V1 - a nice addition
