<script>
	/**
	 * FilterChips - Displays active filters as removable chips
	 *
	 * Shows all currently active filter values with the ability to remove them.
	 */

	import { filters } from '../stores/filters.js';
	import { selectedHost, selectedGenus } from '../stores/results.js';
	import { DETACHABLE_NONE } from '../utils/gallsearch.js';

	// Local state synced with stores
	let filterState = $state({});
	let host = $state(null);
	let genus = $state(null);

	// Sync stores to local state
	$effect(() => {
		const unsub = filters.subscribe((value) => {
			filterState = { ...value };
		});
		return unsub;
	});

	$effect(() => {
		const unsub = selectedHost.subscribe((value) => {
			host = value;
		});
		return unsub;
	});

	$effect(() => {
		const unsub = selectedGenus.subscribe((value) => {
			genus = value;
		});
		return unsub;
	});

	/**
	 * Build list of active filter chips
	 */
	function getActiveChips() {
		const chips = [];

		// Host selection
		if (host) {
			chips.push({
				label: `Host: ${host.name}`,
				category: 'host',
				value: null,
				onRemove: () => selectedHost.set(null)
			});
		}

		// Genus selection
		if (genus) {
			chips.push({
				label: `Genus: ${genus.name}`,
				category: 'genus',
				value: null,
				onRemove: () => selectedGenus.set(null)
			});
		}

		// Locations
		for (const loc of filterState.locations || []) {
			chips.push({
				label: `Location: ${loc}`,
				category: 'locations',
				value: loc,
				onRemove: () => filters.removeFromFilter('locations', loc)
			});
		}

		// Detachable (only if not "none")
		const detachable = filterState.detachable?.[0];
		if (detachable && detachable.value !== DETACHABLE_NONE) {
			chips.push({
				label: `Detachable: ${detachable.value}`,
				category: 'detachable',
				value: detachable,
				onRemove: () => filters.setDetachable({ id: 0, value: DETACHABLE_NONE })
			});
		}

		// Place
		for (const place of filterState.place || []) {
			chips.push({
				label: `Place: ${place}`,
				category: 'place',
				value: place,
				onRemove: () => filters.removeFromFilter('place', place)
			});
		}

		// Family
		for (const fam of filterState.family || []) {
			chips.push({
				label: `Family: ${fam}`,
				category: 'family',
				value: fam,
				onRemove: () => filters.removeFromFilter('family', fam)
			});
		}

		// Season
		for (const s of filterState.season || []) {
			chips.push({
				label: `Season: ${s}`,
				category: 'season',
				value: s,
				onRemove: () => filters.removeFromFilter('season', s)
			});
		}

		// Textures
		for (const t of filterState.textures || []) {
			chips.push({
				label: `Texture: ${t}`,
				category: 'textures',
				value: t,
				onRemove: () => filters.removeFromFilter('textures', t)
			});
		}

		// Alignment
		for (const a of filterState.alignment || []) {
			chips.push({
				label: `Alignment: ${a}`,
				category: 'alignment',
				value: a,
				onRemove: () => filters.removeFromFilter('alignment', a)
			});
		}

		// Form
		for (const f of filterState.form || []) {
			chips.push({
				label: `Form: ${f}`,
				category: 'form',
				value: f,
				onRemove: () => filters.removeFromFilter('form', f)
			});
		}

		// Walls
		for (const w of filterState.walls || []) {
			chips.push({
				label: `Walls: ${w}`,
				category: 'walls',
				value: w,
				onRemove: () => filters.removeFromFilter('walls', w)
			});
		}

		// Cells
		for (const c of filterState.cells || []) {
			chips.push({
				label: `Cells: ${c}`,
				category: 'cells',
				value: c,
				onRemove: () => filters.removeFromFilter('cells', c)
			});
		}

		// Shape
		for (const s of filterState.shape || []) {
			chips.push({
				label: `Shape: ${s}`,
				category: 'shape',
				value: s,
				onRemove: () => filters.removeFromFilter('shape', s)
			});
		}

		// Color
		for (const c of filterState.color || []) {
			chips.push({
				label: `Color: ${c}`,
				category: 'color',
				value: c,
				onRemove: () => filters.removeFromFilter('color', c)
			});
		}

		// Undescribed
		if (filterState.undescribed) {
			chips.push({
				label: 'Only Undescribed',
				category: 'undescribed',
				value: true,
				onRemove: () => filters.toggleUndescribed()
			});
		}

		return chips;
	}

	/**
	 * Clear all filters and selections
	 */
	function clearAll() {
		filters.reset();
		selectedHost.set(null);
		selectedGenus.set(null);
	}

	// Computed list of chips
	let chips = $derived(getActiveChips());
</script>

{#if chips.length > 0}
	<div class="filter-chips flex flex-wrap gap-2 items-center">
		<span class="text-sm text-gray-500">Active filters:</span>
		{#each chips as chip (chip.label)}
			<button
				type="button"
				class="inline-flex items-center gap-1 px-2 py-1 text-sm rounded-full
                       bg-gf-maroon text-white hover:bg-opacity-80 transition-colors"
				onclick={chip.onRemove}
				title="Click to remove"
			>
				<span>{chip.label}</span>
				<svg
					class="w-3 h-3"
					fill="none"
					stroke="currentColor"
					viewBox="0 0 24 24"
					aria-hidden="true"
				>
					<path
						stroke-linecap="round"
						stroke-linejoin="round"
						stroke-width="2"
						d="M6 18L18 6M6 6l12 12"
					/>
				</svg>
			</button>
		{/each}
		<button
			type="button"
			class="text-sm text-red-600 hover:underline ml-2"
			onclick={clearAll}
		>
			Clear all
		</button>
	</div>
{/if}
