<script>
	import { RangeMap } from '$lib/components';
	import ImageGallery from '$lib/components/public/ImageGallery.svelte';
	import SourceList from '$lib/components/public/SourceList.svelte';
	import ExternalLinks from '$lib/components/public/ExternalLinks.svelte';
	import TaxonomyBreadcrumb from '$lib/components/public/TaxonomyBreadcrumb.svelte';
	import SpeciesSynonymy from '$lib/components/public/SpeciesSynonymy.svelte';
	import DataCompletenessIndicator from '$lib/components/public/DataCompletenessIndicator.svelte';
	import EditButton from '$lib/components/public/EditButton.svelte';
	import InfoTip from '$lib/components/public/InfoTip.svelte';
	import ErrorMessage from '$lib/components/public/ErrorMessage.svelte';

	let { data } = $props();

	// Selected source state - reset when data changes (e.g., navigating to different host)
	let selectedSourceId = $state(null);

	$effect(() => {
		selectedSourceId = data.defaultSourceId;
	});

	/**
	 * Get completeness level based on datacomplete flag
	 */
	function getCompletenessLevel(datacomplete) {
		return datacomplete ? 'complete' : 'unknown';
	}
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

<div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
	{#if data.error}
		<ErrorMessage message={data.error} />
	{:else if data.host}
		<!-- Main Content Grid -->
		<div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
			<!-- Left Column: Details -->
			<div class="lg:col-span-2 space-y-6">
				<!-- Header: Name + Status -->
				<div class="flex items-start justify-between gap-4">
					<div class="flex-1">
						<h1 class="text-2xl font-bold text-gf-maroon">
							<em>{data.host.name}</em>
						</h1>
					</div>
					<div class="flex items-center gap-2">
						<EditButton id={data.host.id} type="host" />
						<DataCompletenessIndicator
							level={getCompletenessLevel(data.host.datacomplete)}
							showLabel={false}
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
					<div>
						<span class="font-semibold">Abundance: </span>
						<span class="text-gray-700">{data.host.abundance}</span>
					</div>
				{/if}

				<!-- Associated Galls -->
				{#if data.host.galls && data.host.galls.length > 0}
					<div>
						<div class="flex items-center gap-1 mb-2">
							<span class="font-semibold">Associated Galls:</span>
							<InfoTip text="Gall species that have been found on this host plant." />
						</div>
						<div class="flex flex-wrap gap-2">
							{#each data.host.galls as gall}
								<a
									href="/gall/{gall.id}"
									class="inline-block px-3 py-1 text-sm bg-gray-100 hover:bg-gray-200 rounded-full text-gf-maroon hover:underline transition-colors"
								>
									<em>{gall.name}</em>
								</a>
							{/each}
						</div>
					</div>
				{:else}
					<div>
						<span class="font-semibold">Associated Galls: </span>
						<span class="text-gray-500 italic">None recorded</span>
					</div>
				{/if}

				<!-- Range Map -->
				{#if data.range && data.range.size > 0}
					<div>
						<div class="flex items-center gap-1 mb-2">
							<span class="font-semibold">Range:</span>
							<InfoTip text="Geographic range where this host plant is known to occur." />
						</div>
						<div class="max-w-md">
							<RangeMap inRange={data.range} />
						</div>
					</div>
				{/if}

				<!-- Aliases/Synonymy -->
				{#if data.host.aliases && data.host.aliases.length > 0}
					<SpeciesSynonymy aliases={data.host.aliases} showAllByDefault={true} />
				{/if}
			</div>

			<!-- Right Column: Images -->
			<div class="lg:col-span-1">
				<ImageGallery images={data.images} />
			</div>
		</div>

		<!-- Sources Section -->
		<div class="mt-8">
			<hr class="border-gray-200 mb-6" />
			{#if data.sources && data.sources.length > 0}
				<SourceList sources={data.sources} bind:selectedId={selectedSourceId} />
			{:else}
				<p class="text-gray-500">No sources available for this species.</p>
			{/if}
		</div>

		<!-- External Links Section -->
		<div class="mt-8">
			<hr class="border-gray-200 mb-6" />
			<div class="flex items-center gap-2 mb-4">
				<span class="font-semibold">See Also:</span>
			</div>
			<ExternalLinks name={data.host.name} undescribed={false} />
		</div>
	{:else}
		<ErrorMessage message="Host not found" />
	{/if}
</div>
