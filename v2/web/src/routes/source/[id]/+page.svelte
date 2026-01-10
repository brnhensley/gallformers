<script>
	import EditButton from '$lib/components/public/EditButton.svelte';
	import ErrorMessage from '$lib/components/public/ErrorMessage.svelte';
	import InfoTip from '$lib/components/public/InfoTip.svelte';

	let { data } = $props();

	/**
	 * Sorted species list
	 */
	let sortedSpecies = $derived(
		[...(data.species || [])].sort((a, b) => a.name.localeCompare(b.name))
	);
</script>

<svelte:head>
	{#if data.source}
		{@const description = data.source.citation || `${data.source.title} - Source on Gallformers.`}
		<title>{data.source.title} | Gallformers</title>
		<meta name="description" content={description} />
		<!-- Open Graph (also used by Mastodon, BlueSky, etc.) -->
		<meta property="og:title" content="{data.source.title} | Gallformers" />
		<meta property="og:description" content={description} />
		<meta property="og:type" content="website" />
		<meta property="og:url" content="https://gallformers.org/source/{data.source.id}" />
		<meta property="og:image" content="https://gallformers.org/images/source.svg" />
		<meta property="og:site_name" content="Gallformers" />
	{:else}
		<title>Source Not Found | Gallformers</title>
		<meta name="description" content="Source not found on Gallformers." />
	{/if}
</svelte:head>

<div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
	{#if data.error}
		<ErrorMessage message={data.error} />
	{:else if data.source}
		<!-- Header -->
		<div class="mb-6">
			<div class="flex items-start justify-between gap-4 mb-2">
				<h1 class="text-2xl font-bold text-gf-maroon">{data.source.title}</h1>
				<div class="flex items-center gap-2">
					<EditButton id={data.source.id} type="source" />
					{#if data.source.datacomplete}
						<span
							class="inline-flex items-center px-2 py-1 text-xs font-medium rounded-full bg-green-100 text-green-800"
							title="This source has been comprehensively reviewed and all relevant information entered."
						>
							Complete
						</span>
					{:else}
						<span
							class="inline-flex items-center px-2 py-1 text-xs font-medium rounded-full bg-yellow-100 text-yellow-800"
							title="We are still working on this source so information from the source is potentially still missing."
						>
							In Progress
						</span>
					{/if}
				</div>
			</div>

			{#if data.source.link}
				<a
					href={data.source.link}
					target="_blank"
					rel="noopener noreferrer"
					class="text-blue-600 hover:underline break-all"
				>
					{data.source.link}
				</a>
			{/if}
		</div>

		<!-- Source Info Grid -->
		<div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
			<div>
				<span class="font-semibold text-gray-700">Authors:</span>
				<span class="text-gray-900">{data.source.author || 'Not specified'}</span>
			</div>
			<div>
				<span class="font-semibold text-gray-700">License:</span>
				{#if data.source.licenselink}
					<a
						href={data.source.licenselink}
						target="_blank"
						rel="noopener noreferrer"
						class="text-blue-600 hover:underline"
					>
						{data.source.license || 'View'}
					</a>
				{:else}
					<span class="text-gray-900">{data.source.license || 'Not specified'}</span>
				{/if}
			</div>
			<div>
				<span class="font-semibold text-gray-700">Publication Year:</span>
				<span class="text-gray-900">{data.source.pubyear || 'Not specified'}</span>
			</div>
		</div>

		<!-- Citation -->
		{#if data.source.citation}
			<div class="mb-6">
				<span class="font-semibold text-gray-700">Citation (MLA Form):</span>
				<p class="text-gray-900 italic mt-1">{data.source.citation}</p>
			</div>
		{/if}

		<!-- Connected Species -->
		<div class="mt-8">
			<h2 class="text-lg font-semibold text-gray-800 mb-3">
				Connected Species ({sortedSpecies.length})
			</h2>
			{#if sortedSpecies.length > 0}
				<div class="bg-white rounded border border-gray-200">
					<table class="min-w-full divide-y divide-gray-200">
						<thead class="bg-gray-50">
							<tr>
								<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
									Species Name
								</th>
							</tr>
						</thead>
						<tbody class="bg-white divide-y divide-gray-200">
							{#each sortedSpecies as species}
								{@const isGall = species.taxoncode === 'gall'}
								<tr class="hover:bg-gray-50">
									<td class="px-6 py-4 whitespace-nowrap text-sm">
										<a
											href="{isGall ? '/gall' : '/host'}/{species.id}"
											class="text-blue-600 hover:underline"
										>
											<em>{species.name}</em>
										</a>
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{:else}
				<p class="text-gray-500 italic">No species connected to this source.</p>
			{/if}
		</div>
	{:else}
		<ErrorMessage message="Source not found" />
	{/if}
</div>
