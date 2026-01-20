<script>
	/**
	 * ID Tool Page - Main page for gall identification
	 *
	 * Assembles all components: host/genus pickers, filter panel, chips, and results grid.
	 * URL state sync happens via stores on client-side mount.
	 */

	import { onMount } from 'svelte';
	import { startUrlSync, initFromUrlParams } from './stores/url.js';
	import { resetResults, selectedHost, selectedGenus } from './stores/results.js';
	import HostPicker from './components/HostPicker.svelte';
	import GenusPicker from './components/GenusPicker.svelte';
	import FilterPanel from './components/FilterPanel.svelte';
	import FilterChips from './components/FilterChips.svelte';
	import ResultsGrid from './components/ResultsGrid.svelte';

	// Get data from load function
	let { data } = $props();

	let host = $state(null);
	let genus = $state(null);
	let stopUrlSync = null;

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



	let hasSelection = $derived(host !== null || genus !== null);

	onMount(async () => {
		// Determine which params to use: load function params or browser fallback
		let paramsToUse = data.searchParams;
		
		// Fallback: read directly from window.location if load function got empty params
		// This handles cases where the client-side router didn't pass params correctly
		if (Object.keys(paramsToUse).length === 0 && window.location.search) {
			paramsToUse = Object.fromEntries(new URLSearchParams(window.location.search));
		}

		// Initialize from URL params BEFORE starting URL sync
		// This prevents the race condition where empty store values sync to URL
		if (Object.keys(paramsToUse).length > 0) {
			await initFromUrlParams(paramsToUse);
		}

		// Only start URL sync AFTER initialization is complete
		stopUrlSync = startUrlSync();
		return () => {
			if (stopUrlSync) stopUrlSync();
		};
	});

	function resetForm() {
		resetResults();
	}
</script>

<svelte:head>
	<title>ID Gall | Gallformers</title>
	<meta name="description" content="Identify galls using filter criteria like host plant, location, color, shape, and more." />
	<!-- Open Graph (also used by Mastodon, BlueSky, etc.) -->
	<meta property="og:title" content="ID Gall | Gallformers" />
	<meta property="og:description" content="Identify galls using filter criteria like host plant, location, color, shape, and more." />
	<meta property="og:type" content="website" />
	<meta property="og:url" content="https://gallformers.org/id" />
	<meta property="og:image" content="https://gallformers.org/images/cynipid_R.svg" />
	<meta property="og:site_name" content="Gallformers" />
</svelte:head>

<div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
	<h1 class="text-2xl font-bold text-gf-maroon mb-4">ID Gall</h1>

	<div class="bg-white rounded border border-gray-200 shadow-sm mb-6">
		<div class="p-4 space-y-4">
			<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
				<HostPicker />
				<GenusPicker />
			</div>

			{#if hasSelection}
				<div class="flex items-center">
					<button
						type="button"
						class="px-4 py-2 text-sm bg-red-100 text-red-700 rounded hover:bg-red-200"
						onclick={resetForm}
					>
						Clear
					</button>
				</div>
			{/if}
		</div>
	</div>

	{#if hasSelection}
		<div class="bg-white rounded border border-gray-200 shadow-sm mb-6">
			<div class="p-4">
				<FilterPanel disabled={!hasSelection} />
			</div>
		</div>
	{/if}

	<FilterChips />

	<div class="mt-6">
		<ResultsGrid />
	</div>
</div>
