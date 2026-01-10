<script>
	/**
	 * ResultsGrid - Displays filtered gall results in a responsive grid
	 *
	 * Shows gall cards with images, names, and summary information.
	 * Displays appropriate messages when no results or no search criteria.
	 */

	import {
		finalResults,
		finalResultCount,
		totalCount,
		loading,
		error,
		selectedHost,
		selectedGenus
	} from '../stores/results.js';
	import Alert from '$lib/components/layout/Alert.svelte';

	// Local state from stores
	let results = $state([]);
	let resultCount = $state(0);
	let total = $state(0);
	let isLoading = $state(false);
	let errorMsg = $state(null);
	let host = $state(null);
	let genus = $state(null);

	// Sync stores
	$effect(() => {
		const unsub = finalResults.subscribe((value) => {
			results = value;
		});
		return unsub;
	});

	$effect(() => {
		const unsub = finalResultCount.subscribe((value) => {
			resultCount = value;
		});
		return unsub;
	});

	$effect(() => {
		const unsub = totalCount.subscribe((value) => {
			total = value;
		});
		return unsub;
	});

	$effect(() => {
		const unsub = loading.subscribe((value) => {
			isLoading = value;
		});
		return unsub;
	});

	$effect(() => {
		const unsub = error.subscribe((value) => {
			errorMsg = value;
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
	 * Check if host is marked as data complete
	 */
	function isHostComplete() {
		return host && host.datacomplete;
	}

	/**
	 * Get default image URL for a gall
	 * @param {Object} gall
	 * @returns {string | null}
	 */
	function getDefaultImageUrl(gall) {
		return gall.imageUrl || '/images/noimage.jpg';
	}

	/**
	 * Create a summary of gall characteristics for alt text
	 * @param {Object} gall
	 * @returns {string}
	 */
	function createSummary(gall) {
		const parts = [];
		if (gall.locations && gall.locations.length > 0) {
			parts.push(gall.locations.join(', '));
		}
		if (gall.shapes && gall.shapes.length > 0) {
			parts.push(gall.shapes.join(', '));
		}
		if (gall.colors && gall.colors.length > 0) {
			parts.push(gall.colors.join(', '));
		}
		return parts.join(' - ') || 'Gall species';
	}

	// Derived state for UI
	let hasSearch = $derived(host !== null || genus !== null);
</script>

<div class="results-grid">
	<!-- Results Count -->
	{#if hasSearch}
		<div class="text-sm text-gray-600 mb-4">
			Showing {resultCount} of {total} galls
		</div>
	{/if}

	<!-- Host Data Completeness Warning -->
	{#if host && !isHostComplete()}
		<Alert variant="warning" class="mb-4">
			This host does not yet have all of the known galls added to the database.
		</Alert>
	{/if}

	<!-- Loading State -->
	{#if isLoading}
		<div class="text-center py-8">
			<div
				class="inline-block h-8 w-8 animate-spin rounded-full border-4 border-solid border-gf-maroon border-r-transparent"
			></div>
			<p class="mt-2 text-gray-600">Loading galls...</p>
		</div>
	{:else if errorMsg}
		<!-- Error State -->
		<Alert variant="error">
			{errorMsg}
		</Alert>
	{:else if !hasSearch}
		<!-- No Search Criteria -->
		<Alert variant="info">
			To begin, select a Host or a Genus to see matching galls. Then you can use the filters to
			narrow down the list.
		</Alert>
	{:else if results.length === 0}
		<!-- No Results -->
		<Alert variant="info">
			<p>
				There are no galls that match your filter. It's possible there are no described species that
				fit this set of traits and your gall is undescribed.
			</p>
			<p class="mt-2">
				However, before giving up, try
				<a href="/ref/IDGuide#troubleshooting" class="text-gf-maroon hover:underline"
					>altering your filter choices</a
				>.
			</p>
			{#if isHostComplete()}
				<p class="mt-2">
					To our knowledge, every gall that occurs on the host you have selected is included in the
					database. If you find a gall on this host that is not listed above,
					<a href="mailto:gallformers@gmail.com" class="text-gf-maroon hover:underline"
						>contact us</a
					>.
				</p>
			{/if}
		</Alert>
	{:else}
		<!-- Results Grid -->
		<div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
			{#each results as gall (gall.id)}
				{@const imageUrl = getDefaultImageUrl(gall)}
				{@const summary = createSummary(gall)}
				<div class="bg-white rounded-lg border border-gray-200 shadow-sm overflow-hidden">
					<a href="/gall/{gall.id}" class="block">
						<div class="aspect-square bg-gray-100">
							{#if imageUrl}
								<img
									src={imageUrl}
									alt="{gall.name} - {summary}"
									class="w-full h-full object-cover"
									loading="lazy"
								/>
							{:else}
								<div class="w-full h-full flex items-center justify-center text-gray-400">
									<svg
										class="w-12 h-12"
										fill="none"
										stroke="currentColor"
										viewBox="0 0 24 24"
										aria-hidden="true"
									>
										<path
											stroke-linecap="round"
											stroke-linejoin="round"
											stroke-width="1.5"
											d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
										/>
									</svg>
								</div>
							{/if}
						</div>
					</a>
					<div class="p-3">
						<a href="/gall/{gall.id}" class="block">
							<h3 class="text-sm font-medium text-gf-maroon hover:underline line-clamp-2">
								<em>{gall.name}</em>
							</h3>
						</a>
						{#if !imageUrl && summary}
							<p class="text-xs text-gray-500 mt-1 line-clamp-2">{summary}</p>
						{/if}
						<div class="flex items-center gap-1 mt-2">
							{#if gall.datacomplete}
								<span
									class="text-xs text-green-600"
									title="Data complete - all known information has been added"
								>
									Complete
								</span>
							{/if}
							{#if gall.undescribed}
								<span class="text-xs text-red-600" title="The inducer of this gall is undescribed">
									Undescribed
								</span>
							{/if}
						</div>
					</div>
				</div>
			{/each}
		</div>

		<!-- Results Guidance -->
		<Alert variant="info" class="mt-6">
			<p>
				If none of these results match your gall, you may have found an undescribed species.
				However, before concluding that your gall is not in the database, try
				<a href="/ref/IDGuide#troubleshooting" class="text-gf-maroon hover:underline"
					>altering your filter choices</a
				>.
			</p>
			{#if isHostComplete()}
				<p class="mt-2">
					To our knowledge, every gall that occurs on the host you have selected is included in the
					database. If you find a gall on this host that is not listed above,
					<a href="mailto:gallformers@gmail.com" class="text-gf-maroon hover:underline"
						>contact us</a
					>.
				</p>
			{/if}
		</Alert>
	{/if}
</div>
