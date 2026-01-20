<script>
	import { RangeMap } from '$lib/components';
	import ImageGallery from '$lib/components/public/ImageGallery.svelte';
	import SourceList from '$lib/components/public/SourceList.svelte';
	import ExternalLinks from '$lib/components/public/ExternalLinks.svelte';
	import TaxonomyBreadcrumb from '$lib/components/public/TaxonomyBreadcrumb.svelte';
	import SpeciesSynonymy from '$lib/components/public/SpeciesSynonymy.svelte';
	import DataCompletenessIndicator from '$lib/components/public/DataCompletenessIndicator.svelte';
	import EditButton from '$lib/components/public/EditButton.svelte';
	import ErrorMessage from '$lib/components/public/ErrorMessage.svelte';

	let { data } = $props();

	// Selected source state - reset when data changes (e.g., navigating to different host)
	let selectedSourceId = $state(null);

	// Pagination state for galls list
	const PAGE_SIZE = 10;
	let currentPage = $state(1);

	// Sort galls alphabetically by name
	let sortedGalls = $derived(
		data.host?.galls ? [...data.host.galls].sort((a, b) => a.name.localeCompare(b.name)) : []
	);

	// Paginated galls
	let totalPages = $derived(Math.ceil(sortedGalls.length / PAGE_SIZE));
	let paginatedGalls = $derived(
		sortedGalls.slice((currentPage - 1) * PAGE_SIZE, currentPage * PAGE_SIZE)
	);

	$effect(() => {
		selectedSourceId = data.defaultSourceId;
	});

	// Reset pagination when host changes
	$effect(() => {
		if (data.host) {
			currentPage = 1;
		}
	});

	// Tooltip text matching V1
	const hostCompleteText = 'All galls known to occur on this plant have been added to the database, and can be filtered by Location and Detachable. However, sources and images for galls associated with this host may be incomplete or absent, and other filters may not have been entered comprehensively or at all.';
	const hostIncompleteText = 'We are still working on this species so data might be missing.';
</script>

<svelte:head>
	{#if data.host}
		{@const description = `${data.host.name} - A host plant species on Gallformers.`}
		{@const imageUrl = data.images && data.images.length > 0 ? data.images[0].default : 'https://gallformers.org/images/host.svg'}
		<title>{data.host.name} | Gallformers</title>
		<meta name="description" content={description} />
		<!-- Open Graph (also used by Mastodon, BlueSky, etc.) -->
		<meta property="og:title" content="{data.host.name} | Gallformers" />
		<meta property="og:description" content={description} />
		<meta property="og:type" content="website" />
		<meta property="og:url" content="https://gallformers.org/host/{data.host.id}" />
		<meta property="og:image" content={imageUrl} />
		<meta property="og:site_name" content="Gallformers" />
	{:else}
		<title>Host Not Found | Gallformers</title>
		<meta name="description" content="Host not found on Gallformers." />
	{/if}
</svelte:head>

<div class="mx-auto max-w-7xl px-4 pt-2 sm:px-6 lg:px-8">
	{#if data.error}
		<ErrorMessage message={data.error} />
	{:else if data.host}
		<!-- Main Content Grid -->
		<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-2">
			<!-- Left Column: Details (2/3 width on lg) -->
			<div class="md:col-span-1 lg:col-span-2">
				<!-- Header: Name + Status -->
				<div class="flex items-start justify-between gap-4">
					<div class="flex-1">
						<h2 class="text-2xl font-bold">
							<a
								href="/id?hostOrTaxon={encodeURIComponent(data.host.name)}&type=host"
								class="hover:underline"
							>
								<em>{data.host.name}</em>
							</a>
						</h2>
					</div>
					<div class="flex items-center gap-2 me-1">
						<EditButton id={data.host.id} type="host" />
						<DataCompletenessIndicator
							complete={data.host.datacomplete}
							tooltipText={data.host.datacomplete ? hostCompleteText : hostIncompleteText}
						/>
					</div>
				</div>

				<!-- Taxonomy Breadcrumb -->
				{#if data.taxonomy}
					<TaxonomyBreadcrumb
						family={data.taxonomy.family}
						genus={data.taxonomy.genus}
						section={data.taxonomy.section}
						showSection={!!data.taxonomy.section}
					/>
				{/if}

				<!-- Abundance -->
				{#if data.host.abundance}
					<div class="py-0.5">
						<strong>Abundance:</strong> {data.host.abundance}
					</div>
				{/if}

				<!-- Aliases/Synonymy -->
				{#if data.host.aliases && data.host.aliases.length > 0}
					<SpeciesSynonymy aliases={data.host.aliases} showAllByDefault={true} />
				{/if}

				<!-- Associated Galls - Paginated Table -->
				<div class="pt-2">
					{#if sortedGalls.length > 0}
						<div class="overflow-hidden rounded border border-gray-200">
							<table class="min-w-full divide-y divide-gray-200">
								<thead class="bg-cadet-blue">
									<tr>
										<th
											class="px-3 py-2 text-left text-sm font-medium text-gray-900"
										>
											Gall
										</th>
									</tr>
								</thead>
								<tbody class="bg-white divide-y divide-gray-200">
									{#each paginatedGalls as gall, i}
										<tr class="hover:bg-gray-50 {i % 2 === 1 ? 'bg-gray-50' : ''}">
											<td class="px-3 py-2 text-sm">
												<a
													href="/gall/{gall.id}"
													class="hover:underline"
												>
													<em>{gall.name}</em>
												</a>
											</td>
										</tr>
									{/each}
								</tbody>
							</table>
							<!-- Pagination Controls -->
							{#if totalPages > 1}
								<div
									class="flex items-center justify-between px-3 py-1 bg-white border-t border-gray-200"
								>
									<div class="text-sm">
										{(currentPage - 1) * PAGE_SIZE + 1}-{Math.min(
											currentPage * PAGE_SIZE,
											sortedGalls.length
										)} of {sortedGalls.length}
									</div>
									<div class="flex items-center gap-2">
										<button
											class="px-2 py-0.5 text-sm border rounded hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed"
											disabled={currentPage === 1}
											onclick={() => (currentPage = currentPage - 1)}
										>
											Previous
										</button>
										<span class="text-sm">
											Page {currentPage} of {totalPages}
										</span>
										<button
											class="px-2 py-0.5 text-sm border rounded hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed"
											disabled={currentPage === totalPages}
											onclick={() => (currentPage = currentPage + 1)}
										>
											Next
										</button>
									</div>
								</div>
							{/if}
						</div>
					{:else}
						<p class="italic">No galls recorded for this host.</p>
					{/if}
				</div>
			</div>

			<!-- Right Column: Images + Range Map (1/3 width on lg) -->
			<div class="md:col-span-1 lg:col-span-1 border rounded p-1 flex flex-col gap-2">
				<ImageGallery images={data.images} />

				<!-- Range Map -->
				{#if data.range && data.range.size > 0}
					<div class="mt-auto">
						<div>Range:</div>
						<RangeMap inRange={data.range} />
					</div>
				{/if}
			</div>
		</div>

		<hr class="border-gray-200 my-4" />

		<!-- Sources Section -->
		{#if data.sources && data.sources.length > 0}
			<SourceList sources={data.sources} bind:selectedId={selectedSourceId} />
		{:else}
			<p class="italic">No sources available for this species.</p>
		{/if}

		<hr class="border-gray-200 my-4" />

		<!-- External Links Section -->
		<div class="mb-2">
			<strong>See Also:</strong>
		</div>
		<ExternalLinks name={data.host.name} undescribed={false} />
	{:else}
		<ErrorMessage message="Host not found" />
	{/if}
</div>
