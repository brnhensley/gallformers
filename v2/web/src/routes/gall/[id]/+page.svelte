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

	// Detachable value mapping
	const detachableValues = {
		0: 'Integral',
		1: 'Detachable',
		2: 'Both'
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
		return value === 2;
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

	/**
	 * Get completeness level based on datacomplete flag
	 */
	function getCompletenessLevel(datacomplete) {
		return datacomplete ? 'complete' : 'unknown';
	}
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

<div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
	{#if data.error}
		<ErrorMessage message={data.error} />
	{:else if data.gall}
		<!-- Phenology Tool Link -->
		<div class="mb-4 text-center">
			<a
				href="https://megachile.shinyapps.io/doycalc/"
				target="_blank"
				rel="noreferrer"
				class="text-sm text-gf-maroon hover:underline"
			>
				<span class="hidden md:inline">
					Explore the seasonal timing of gall development and emergence with our phenology tool
				</span>
				<span class="md:hidden" title="Explore the seasonal timing of gall development and emergence with our phenology tool">
					Phenology Tool
				</span>
			</a>
		</div>

		<!-- Main Content Grid -->
		<div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
			<!-- Left Column: Details -->
			<div class="lg:col-span-2 space-y-6">
				<!-- Header: Name + Status -->
				<div class="flex items-start justify-between gap-4">
					<div class="flex-1">
						<h1 class="text-2xl font-bold text-gf-maroon">
							<em>{data.gall.name}</em>
						</h1>
					</div>
					<div class="flex items-center gap-2">
						<EditButton id={data.gall.id} type="gall" />
						<DataCompletenessIndicator
							level={getCompletenessLevel(data.gall.datacomplete)}
							showLabel={false}
						/>
					</div>
				</div>

				<!-- Undescribed Warning -->
				{#if data.gall.undescribed}
					<div class="bg-red-50 border border-red-200 rounded-md p-4">
						<div class="flex flex-wrap items-center gap-3">
							<span class="text-red-700">
								The inducer of this gall is unknown or undescribed.
							</span>
							<button
								type="button"
								onclick={copyGallformersCode}
								class="px-3 py-1 text-sm border border-gray-300 rounded-md bg-white hover:bg-gray-50 text-gray-700 transition-colors"
							>
								Copy gallformers code
							</button>
						</div>
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
						<span class="font-semibold">Hosts: </span>
						<em>
							{#each data.gall.hosts as host, i}
								<a href="/host/{host.id}" class="text-blue-600 hover:underline">
									{host.name}
								</a>{i < data.gall.hosts.length - 1 ? ' / ' : ''}
							{/each}
						</em>
						<EditButton id={data.gall.id} type="gallhost" />
					</div>
				{/if}

				<!-- Morphological Characteristics -->
				<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
					<!-- Column 1 -->
					<div class="space-y-2">
						<div>
							<span class="font-semibold">Detachable: </span>
							<span>{getDetachableDisplay(data.gall.detachable)}</span>
							{#if isDetachableBoth(data.gall.detachable)}
								<InfoTip text="This gall can be both detachable and integral depending on what stage of its lifecycle it is in." />
							{/if}
						</div>
						<div>
							<span class="font-semibold">Color: </span>
							<span>{formatFields(data.gall.colors)}</span>
						</div>
						<div>
							<span class="font-semibold">Texture: </span>
							<span>{formatFields(data.gall.textures)}</span>
						</div>
						<div>
							<span class="font-semibold">Shape: </span>
							<span>{formatFields(data.gall.shapes)}</span>
						</div>
						<div>
							<span class="font-semibold">Season: </span>
							<span>{formatFields(data.gall.seasons)}</span>
						</div>
					</div>

					<!-- Column 2 -->
					<div class="space-y-2">
						<div>
							<span class="font-semibold">Alignment: </span>
							<span>{formatFields(data.gall.alignments)}</span>
						</div>
						<div>
							<span class="font-semibold">Walls: </span>
							<span>{formatFields(data.gall.walls)}</span>
						</div>
						<div>
							<span class="font-semibold">Location: </span>
							<span>{formatFields(data.gall.locations)}</span>
						</div>
						<div>
							<span class="font-semibold">Form: </span>
							<span>{formatFields(data.gall.forms)}</span>
						</div>
						<div>
							<span class="font-semibold">Cells: </span>
							<span>{formatFields(data.gall.cells)}</span>
						</div>
					</div>
				</div>

				<!-- Range Map -->
				{#if data.range && data.range.size > 0}
					<div>
						<div class="flex items-center gap-1 mb-2">
							<span class="font-semibold">Possible Range:</span>
							<InfoTip text="The gall's range is computed from the range of all hosts that the gall occurs on. In some cases we have evidence that the gall does not occur across the full range of the hosts and we will remove these places from the range. For undescribed species we will show the expected range based on hosts plus where the galls have been observed. All of this said, the exact ranges for most galls is uncertain." />
						</div>
						<div class="max-w-md">
							<RangeMap inRange={data.range} excludedRange={data.excludedRange} />
						</div>
					</div>
				{/if}

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
			<ExternalLinks name={data.gall.name} undescribed={data.gall.undescribed} />
		</div>
	{:else}
		<ErrorMessage message="Gall not found" />
	{/if}
</div>
