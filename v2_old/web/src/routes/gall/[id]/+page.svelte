<script>
	import { toast } from '$lib/components';
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

	// Selected source state - reset when data changes (e.g., navigating to different gall)
	let selectedSourceId = $state(null);

	$effect(() => {
		selectedSourceId = data.defaultSourceId;
	});

	// Detachable value mapping (matches V1: 0=None, 1=Integral, 2=Detachable, 3=Both)
	const detachableValues = {
		0: '',
		1: 'Integral',
		2: 'Detachable',
		3: 'Both'
	};

	/**
	 * Get display value for detachable field
	 */
	function getDetachableDisplay(value) {
		if (value === null || value === undefined) return '';
		return detachableValues[value] || '';
	}

	/**
	 * Check if detachable is "Both"
	 */
	function isDetachableBoth(value) {
		return value === 3;
	}

	/**
	 * Format filter fields (colors, shapes, etc.) for display
	 */
	function formatFields(fields) {
		if (!fields || fields.length === 0) return '';
		return fields.map((f) => f.field).join(', ');
	}

	/**
	 * Copy gallformers code to clipboard for undescribed species
	 */
	async function copyGallformersCode() {
		if (!data.gall || !data.taxonomy) return;

		// Extract code: remove genus name and any trailing parenthetical
		const code = data.gall.name
			.replace(data.taxonomy.genus?.name || '', '')
			.trim()
			.replace(/ \([^)]+\)$/, '');

		try {
			await navigator.clipboard.writeText(code);
			toast.success('Code copied to clipboard');
		} catch (err) {
			console.error('Failed to copy:', err);
			toast.error('Failed to copy code');
		}
	}

	// Tooltip text matching V1
	const gallCompleteText = 'All sources containing unique information relevant to this gall have been added and are reflected in its associated data. However, filter criteria may not be comprehensive in every field.';
	const gallIncompleteText = 'We are still working on this species so data is missing.';
</script>

<svelte:head>
	{#if data.gall}
		{@const description = `${data.gall.name} - A gall species on Gallformers.${data.gall.undescribed ? ' The inducer of this gall is unknown or undescribed.' : ''}`}
		{@const imageUrl = data.images && data.images.length > 0 ? data.images[0].default : 'https://gallformers.org/images/cynipid_R.svg'}
		<title>{data.gall.name} | Gallformers</title>
		<meta name="description" content={description} />
		<!-- Open Graph (also used by Mastodon, BlueSky, etc.) -->
		<meta property="og:title" content="{data.gall.name} | Gallformers" />
		<meta property="og:description" content={description} />
		<meta property="og:type" content="website" />
		<meta property="og:url" content="https://gallformers.org/gall/{data.gall.id}" />
		<meta property="og:image" content={imageUrl} />
		<meta property="og:site_name" content="Gallformers" />
	{:else}
		<title>Gall Not Found | Gallformers</title>
		<meta name="description" content="Gall not found on Gallformers." />
	{/if}
</svelte:head>

<div class="mx-auto max-w-7xl px-4 pt-2 sm:px-6 lg:px-8">
	{#if data.error}
		<ErrorMessage message={data.error} />
	{:else if data.gall}
		<!-- Main Content Grid -->
		<div class="grid grid-cols-1 lg:grid-cols-3 gap-2">
			<!-- Left Column: Details -->
			<div class="lg:col-span-2 space-y-1">
				<!-- Header: Name + Status -->
				<div class="flex items-start justify-between gap-4">
					<div class="flex-1">
						<h2 class="text-2xl font-bold">
							<em>{data.gall.name}</em>
						</h2>
					</div>
					<div class="flex items-center gap-2">
						<EditButton id={data.gall.id} type="gall" />
						<DataCompletenessIndicator
							complete={data.gall.datacomplete}
							tooltipText={data.gall.datacomplete ? gallCompleteText : gallIncompleteText}
						/>
					</div>
				</div>

				<!-- Undescribed Warning -->
				{#if data.gall.undescribed}
					<div>
						<span class="text-red-600">The inducer of this gall is unknown or undescribed.</span>
						<button
							type="button"
							onclick={copyGallformersCode}
							class="ml-2 px-2 py-0.5 text-sm border border-gray-400 rounded bg-white hover:bg-gray-50 text-gray-600"
						>
							Copy gallformers code
						</button>
					</div>
				{/if}

				<!-- Taxonomy Breadcrumb -->
				{#if data.taxonomy}
					<TaxonomyBreadcrumb
						family={data.taxonomy.family}
						genus={data.taxonomy.genus}
						section={data.taxonomy.section}
						showSection={!!data.taxonomy.section}
					/>
				{/if}

				<!-- Hosts -->
				{#if data.gall.hosts && data.gall.hosts.length > 0}
					<div>
						<strong>Hosts:</strong>{' '}
						<em>
							{#each data.gall.hosts as host, i}
								<a href="/host/{host.id}" class="hover:underline">
									{host.name}
								</a>{i < data.gall.hosts.length - 1 ? ' / ' : ''}
							{/each}
						</em>
						<EditButton id={data.gall.id} type="gallhost" />
					</div>
				{/if}

				<!-- Morphological Characteristics - 3 column layout like V1 -->
				<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-x-2">
					<!-- Column 1 -->
					<div>
						<div class="py-0.5">
							<strong>Detachable:</strong> {getDetachableDisplay(data.gall.detachable)}
							{#if isDetachableBoth(data.gall.detachable)}
								<InfoTip text="This gall can be both detachable and integral depending on what stage of its lifecycle it is in." />
							{/if}
						</div>
						<div class="py-0.5">
							<strong>Color:</strong> {formatFields(data.gall.colors)}
						</div>
						<div class="py-0.5">
							<strong>Texture:</strong> {formatFields(data.gall.textures)}
						</div>
						<div class="py-0.5">
							<strong>Abundance:</strong> {data.gall.abundance || ''}
						</div>
						<div class="py-0.5">
							<strong>Shape:</strong> {formatFields(data.gall.shapes)}
						</div>
						<div class="py-0.5">
							<strong>Season:</strong> {formatFields(data.gall.seasons)}
						</div>
						{#if data.relatedGalls && data.relatedGalls.length > 0}
							<div class="py-0.5">
								<strong>Related:</strong>{' '}
								{#each data.relatedGalls as related, i}
									<a href="/gall/{related.id}" class="hover:underline">
										{related.name}
									</a>{i < data.relatedGalls.length - 1 ? ', ' : ''}
								{/each}
							</div>
						{/if}
					</div>

					<!-- Column 2 -->
					<div>
						<div class="py-0.5">
							<strong>Alignment:</strong> {formatFields(data.gall.alignments)}
						</div>
						<div class="py-0.5">
							<strong>Walls:</strong> {formatFields(data.gall.walls)}
						</div>
						<div class="py-0.5">
							<strong>Location:</strong> {formatFields(data.gall.locations)}
						</div>
						<div class="py-0.5">
							<strong>Form:</strong> {formatFields(data.gall.forms)}
						</div>
						<div class="py-0.5">
							<strong>Cells:</strong> {formatFields(data.gall.cells)}
						</div>
					</div>

					<!-- Column 3 - Range Map -->
					<div class="p-0 m-0">
						<div class="py-0.5">
							<strong>Possible Range:</strong>
							<InfoTip text="The gall's range is computed from the range of all hosts that the gall occurs on. In some cases we have evidence that the gall does not occur across the full range of the hosts and we will remove these places from the range. For undescribed species we will show the expected range based on hosts plus where the galls have been observed. All of this said, the exact ranges for most galls is uncertain." />
						</div>
						{#if data.range && data.range.size > 0}
							<RangeMap inRange={data.range} excludedRange={data.excludedRange} />
						{/if}
					</div>
				</div>

				<!-- Aliases/Synonymy -->
				{#if data.gall.aliases && data.gall.aliases.length > 0}
					<SpeciesSynonymy aliases={data.gall.aliases} showAllByDefault={true} />
				{/if}
			</div>

			<!-- Right Column: Images -->
			<div class="lg:col-span-1">
				<ImageGallery images={data.images} />
			</div>
		</div>

		<!-- Sources Section -->
		<div class="mt-4">
			<hr class="border-gray-200 mb-4" />
			{#if data.sources && data.sources.length > 0}
				<SourceList sources={data.sources} bind:selectedId={selectedSourceId} />
			{:else}
				<p class="italic">No sources available for this species.</p>
			{/if}
		</div>

		<!-- External Links Section -->
		<div class="mt-4">
			<hr class="border-gray-200 mb-4" />
			<div class="mb-2">
				<strong>See Also:</strong>
			</div>
			<ExternalLinks name={data.gall.name} undescribed={data.gall.undescribed} />
		</div>
	{:else}
		<ErrorMessage message="Gall not found" />
	{/if}
</div>
