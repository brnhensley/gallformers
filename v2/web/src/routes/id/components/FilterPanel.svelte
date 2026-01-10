<script>
	/**
	 * FilterPanel - All filter controls for the ID tool
	 *
	 * Contains location, detachable, place, family filters (always visible)
	 * and advanced filters (collapsible) for texture, alignment, walls, cells, etc.
	 */

	import { onMount } from 'svelte';
	import InfoTip from '$lib/components/public/InfoTip.svelte';
	import { filters, EMPTY_QUERY } from '../stores/filters.js';
	import { galls } from '../stores/results.js';
	import {
		LEAF_ANYWHERE,
		GALL_FORM,
		DETACHABLE_NONE,
		DETACHABLE_INTEGRAL,
		DETACHABLE_DETACHABLE,
		DETACHABLE_BOTH
	} from '../utils/gallsearch.js';

	let { apiBase = '/api/v2', disabled = false } = $props();

	// Filter options loaded from API
	let locations = $state([]);
	let colors = $state([]);
	let seasons = $state([]);
	let shapes = $state([]);
	let textures = $state([]);
	let alignments = $state([]);
	let walls = $state([]);
	let cells = $state([]);
	let forms = $state([]);
	let places = $state([]);

	// Derived from current gall results
	let families = $derived(() => {
		const gallList = $galls || [];
		const uniqueFamilies = [...new Set(gallList.map((g) => g.family).filter(Boolean))];
		return uniqueFamilies.sort();
	});

	// UI state
	let showAdvanced = $state(false);
	let loading = $state(true);

	// Local filter state synced with store
	let filterState = $state({ ...EMPTY_QUERY });

	// Sync store to local state
	$effect(() => {
		const unsub = filters.subscribe((value) => {
			filterState = { ...value };
		});
		return unsub;
	});

	// Detachable options
	const detachableOptions = [
		{ id: 0, value: DETACHABLE_NONE, label: 'Any' },
		{ id: 1, value: DETACHABLE_INTEGRAL, label: 'Integral' },
		{ id: 2, value: DETACHABLE_DETACHABLE, label: 'Detachable' },
		{ id: 3, value: DETACHABLE_BOTH, label: 'Both' }
	];

	onMount(async () => {
		await loadFilterOptions();
	});

	/**
	 * Load all filter options from API
	 */
	async function loadFilterOptions() {
		loading = true;
		try {
			const [locRes, colRes, seaRes, shaRes, texRes, aliRes, walRes, celRes, forRes, plaRes] =
				await Promise.all([
					fetch(`${apiBase}/filter-fields/location`),
					fetch(`${apiBase}/filter-fields/color`),
					fetch(`${apiBase}/filter-fields/season`),
					fetch(`${apiBase}/filter-fields/shape`),
					fetch(`${apiBase}/filter-fields/texture`),
					fetch(`${apiBase}/filter-fields/alignment`),
					fetch(`${apiBase}/filter-fields/walls`),
					fetch(`${apiBase}/filter-fields/cells`),
					fetch(`${apiBase}/filter-fields/form`),
					fetch(`${apiBase}/places`)
				]);

			if (locRes.ok) locations = await locRes.json();
			if (colRes.ok) colors = await colRes.json();
			if (seaRes.ok) seasons = await seaRes.json();
			if (shaRes.ok) shapes = await shaRes.json();
			if (texRes.ok) textures = await texRes.json();
			if (aliRes.ok) alignments = await aliRes.json();
			if (walRes.ok) walls = await walRes.json();
			if (celRes.ok) cells = await celRes.json();
			if (forRes.ok) forms = await forRes.json();
			if (plaRes.ok) places = await plaRes.json();
		} catch (err) {
			console.error('Error loading filter options:', err);
		} finally {
			loading = false;
		}
	}

	/**
	 * Update a filter field (for array fields)
	 * @param {string} field
	 * @param {string[]} values
	 */
	function updateFilter(field, values) {
		filters.setFilter(field, values);
	}

	/**
	 * Toggle a value in a multi-select filter
	 * @param {string} field
	 * @param {string} value
	 */
	function toggleFilterValue(field, value) {
		filters.toggleFilter(field, value);
	}

	/**
	 * Update detachable filter
	 * @param {string} value
	 */
	function updateDetachable(value) {
		const opt = detachableOptions.find((o) => o.value === value) || detachableOptions[0];
		filters.setDetachable(opt);
	}

	/**
	 * Check if advanced filters have any selections
	 */
	function hasAdvancedSelections() {
		return (
			filterState.alignment.length > 0 ||
			filterState.cells.length > 0 ||
			filterState.color.length > 0 ||
			filterState.form.length > 0 ||
			filterState.season.length > 0 ||
			filterState.shape.length > 0 ||
			filterState.textures.length > 0 ||
			filterState.walls.length > 0 ||
			filterState.undescribed
		);
	}

	/**
	 * Reset all filters
	 */
	function resetAll() {
		filters.reset();
	}

	/**
	 * Get location options with special "leaf (anywhere)" option
	 */
	function getLocationOptions() {
		const opts = locations.map((l) => l.field);
		return [...opts, LEAF_ANYWHERE].sort();
	}

	/**
	 * Get form options with special "gall" option
	 */
	function getFormOptions() {
		const opts = forms.map((f) => f.field);
		return [...opts, GALL_FORM].sort();
	}
</script>

<div class="filter-panel space-y-4" class:opacity-50={disabled || loading}>
	{#if loading}
		<div class="text-center text-gray-500 py-4">Loading filter options...</div>
	{:else}
		<!-- Primary Filters (Always Visible) -->
		<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
			<!-- Location -->
			<div>
				<label class="block text-sm font-medium text-gray-700 mb-1">
					Location(s)
					<InfoTip text="Where on the host the gall is found." />
				</label>
				<select
					multiple
					class="w-full h-24 rounded-md border-gray-300 shadow-sm focus:border-gf-maroon focus:ring-gf-maroon text-sm"
					disabled={disabled}
					onchange={(e) => {
						const selected = Array.from(e.target.selectedOptions).map((o) => o.value);
						updateFilter('locations', selected);
					}}
				>
					{#each getLocationOptions() as loc}
						<option value={loc} selected={filterState.locations.includes(loc)}>{loc}</option>
					{/each}
				</select>
			</div>

			<!-- Detachable -->
			<div>
				<label class="block text-sm font-medium text-gray-700 mb-1">
					Detachable
					<InfoTip text="Can the gall be removed from the host without cutting?" />
				</label>
				<select
					class="w-full rounded-md border-gray-300 shadow-sm focus:border-gf-maroon focus:ring-gf-maroon text-sm"
					disabled={disabled}
					value={filterState.detachable[0]?.value || DETACHABLE_NONE}
					onchange={(e) => updateDetachable(e.target.value)}
				>
					{#each detachableOptions as opt}
						<option value={opt.value}>{opt.label}</option>
					{/each}
				</select>
			</div>

			<!-- Place -->
			<div>
				<label class="block text-sm font-medium text-gray-700 mb-1">
					Place
					<InfoTip text="Where did you see the Gall? (US states or CAN provinces)." />
				</label>
				<select
					class="w-full rounded-md border-gray-300 shadow-sm focus:border-gf-maroon focus:ring-gf-maroon text-sm"
					disabled={disabled}
					value={filterState.place[0] || ''}
					onchange={(e) => updateFilter('place', e.target.value ? [e.target.value] : [])}
				>
					<option value="">Any</option>
					{#each places as place}
						<option value={place.name}>{place.name}</option>
					{/each}
				</select>
			</div>

			<!-- Family -->
			<div>
				<label class="block text-sm font-medium text-gray-700 mb-1">
					Gall Family
					<InfoTip text="The taxonomic Family of the Gallformer." />
				</label>
				<select
					class="w-full rounded-md border-gray-300 shadow-sm focus:border-gf-maroon focus:ring-gf-maroon text-sm"
					disabled={disabled}
					value={filterState.family[0] || ''}
					onchange={(e) => updateFilter('family', e.target.value ? [e.target.value] : [])}
				>
					<option value="">Any</option>
					{#each families() as fam}
						<option value={fam}>{fam}</option>
					{/each}
				</select>
			</div>
		</div>

		<!-- Advanced Filters Toggle -->
		<div class="flex justify-between items-center pt-2">
			<button
				type="button"
				class="text-sm text-gf-maroon hover:underline"
				onclick={() => (showAdvanced = !showAdvanced)}
			>
				{showAdvanced ? 'Hide Advanced Filters' : 'Show Advanced Filters'}
			</button>
			<button
				type="button"
				class="text-sm text-red-600 hover:underline"
				onclick={resetAll}
				disabled={disabled}
			>
				Clear All Filters
			</button>
		</div>

		{#if !showAdvanced && hasAdvancedSelections()}
			<p class="text-sm text-red-600">You have active selections in the hidden filters.</p>
		{/if}

		<!-- Advanced Filters (Collapsible) -->
		{#if showAdvanced}
			<div class="border-t pt-4 mt-4">
				<p class="text-sm text-gray-500 italic mb-4">
					Be aware that many galls do not have associated information for all of the below
					properties.
				</p>

				<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
					<!-- Season -->
					<div>
						<label class="block text-sm font-medium text-gray-700 mb-1">
							Season
							<InfoTip text="The season when the gall first appears." />
						</label>
						<select
							class="w-full rounded-md border-gray-300 shadow-sm focus:border-gf-maroon focus:ring-gf-maroon text-sm"
							disabled={disabled}
							value={filterState.season[0] || ''}
							onchange={(e) => updateFilter('season', e.target.value ? [e.target.value] : [])}
						>
							<option value="">Any</option>
							{#each seasons as s}
								<option value={s.field}>{s.field}</option>
							{/each}
						</select>
					</div>

					<!-- Texture -->
					<div>
						<label class="block text-sm font-medium text-gray-700 mb-1">
							Texture(s)
							<InfoTip text="The look and feel of the gall." />
						</label>
						<select
							multiple
							class="w-full h-24 rounded-md border-gray-300 shadow-sm focus:border-gf-maroon focus:ring-gf-maroon text-sm"
							disabled={disabled}
							onchange={(e) => {
								const selected = Array.from(e.target.selectedOptions).map((o) => o.value);
								updateFilter('textures', selected);
							}}
						>
							{#each textures as t}
								<option value={t.field} selected={filterState.textures.includes(t.field)}
									>{t.field}</option
								>
							{/each}
						</select>
					</div>

					<!-- Alignment -->
					<div>
						<label class="block text-sm font-medium text-gray-700 mb-1">
							Alignment
							<InfoTip text="How the gall is positioned relative to the host substrate." />
						</label>
						<select
							class="w-full rounded-md border-gray-300 shadow-sm focus:border-gf-maroon focus:ring-gf-maroon text-sm"
							disabled={disabled}
							value={filterState.alignment[0] || ''}
							onchange={(e) => updateFilter('alignment', e.target.value ? [e.target.value] : [])}
						>
							<option value="">Any</option>
							{#each alignments as a}
								<option value={a.field}>{a.field}</option>
							{/each}
						</select>
					</div>

					<!-- Form -->
					<div>
						<label class="block text-sm font-medium text-gray-700 mb-1">
							Form
							<InfoTip text="The overall form of the gall." />
						</label>
						<select
							class="w-full rounded-md border-gray-300 shadow-sm focus:border-gf-maroon focus:ring-gf-maroon text-sm"
							disabled={disabled}
							value={filterState.form[0] || ''}
							onchange={(e) => updateFilter('form', e.target.value ? [e.target.value] : [])}
						>
							<option value="">Any</option>
							{#each getFormOptions() as f}
								<option value={f}>{f}</option>
							{/each}
						</select>
					</div>

					<!-- Walls -->
					<div>
						<label class="block text-sm font-medium text-gray-700 mb-1">
							Walls
							<InfoTip
								text="What the walls between the outside and the inside of the gall are like."
							/>
						</label>
						<select
							class="w-full rounded-md border-gray-300 shadow-sm focus:border-gf-maroon focus:ring-gf-maroon text-sm"
							disabled={disabled}
							value={filterState.walls[0] || ''}
							onchange={(e) => updateFilter('walls', e.target.value ? [e.target.value] : [])}
						>
							<option value="">Any</option>
							{#each walls as w}
								<option value={w.field}>{w.field}</option>
							{/each}
						</select>
					</div>

					<!-- Cells -->
					<div>
						<label class="block text-sm font-medium text-gray-700 mb-1">
							Cells
							<InfoTip text="The number of internal chambers that the gall contains." />
						</label>
						<select
							class="w-full rounded-md border-gray-300 shadow-sm focus:border-gf-maroon focus:ring-gf-maroon text-sm"
							disabled={disabled}
							value={filterState.cells[0] || ''}
							onchange={(e) => updateFilter('cells', e.target.value ? [e.target.value] : [])}
						>
							<option value="">Any</option>
							{#each cells as c}
								<option value={c.field}>{c.field}</option>
							{/each}
						</select>
					</div>

					<!-- Shape -->
					<div>
						<label class="block text-sm font-medium text-gray-700 mb-1">
							Shape
							<InfoTip text="The overall shape of the gall." />
						</label>
						<select
							class="w-full rounded-md border-gray-300 shadow-sm focus:border-gf-maroon focus:ring-gf-maroon text-sm"
							disabled={disabled}
							value={filterState.shape[0] || ''}
							onchange={(e) => updateFilter('shape', e.target.value ? [e.target.value] : [])}
						>
							<option value="">Any</option>
							{#each shapes as s}
								<option value={s.field}>{s.field}</option>
							{/each}
						</select>
					</div>

					<!-- Color -->
					<div>
						<label class="block text-sm font-medium text-gray-700 mb-1">
							Color
							<InfoTip text="The outside color of the gall." />
						</label>
						<select
							class="w-full rounded-md border-gray-300 shadow-sm focus:border-gf-maroon focus:ring-gf-maroon text-sm"
							disabled={disabled}
							value={filterState.color[0] || ''}
							onchange={(e) => updateFilter('color', e.target.value ? [e.target.value] : [])}
						>
							<option value="">Any</option>
							{#each colors as c}
								<option value={c.field}>{c.field}</option>
							{/each}
						</select>
					</div>
				</div>

				<!-- Undescribed Checkbox -->
				<div class="mt-4">
					<label class="inline-flex items-center">
						<input
							type="checkbox"
							class="rounded border-gray-300 text-gf-maroon focus:ring-gf-maroon"
							checked={filterState.undescribed}
							disabled={disabled}
							onchange={() => filters.toggleUndescribed()}
						/>
						<span class="ml-2 text-sm text-gray-700">
							Only Undescribed
							<InfoTip text="Show only undescribed galls." />
						</span>
					</label>
				</div>
			</div>
		{/if}
	{/if}
</div>
