<script>
	import EditButton from '$lib/components/public/EditButton.svelte';
	import ErrorMessage from '$lib/components/public/ErrorMessage.svelte';

	let { data } = $props();

	/**
	 * Sorted hosts list
	 */
	let sortedHosts = $derived(
		[...(data.hosts || [])].sort((a, b) => a.name.localeCompare(b.name))
	);

	/**
	 * Format parent info text
	 */
	function formatParentInfo(place, parent) {
		if (!parent) return '';
		const article = parent.name === 'United States' ? 'the ' : '';
		return `a ${place.type} of ${article}${parent.name}`;
	}
</script>

<svelte:head>
	{#if data.place}
		{@const description = `${data.place.name} (${data.place.code}) - Geographic location on Gallformers.`}
		<title>{data.place.name} | Gallformers</title>
		<meta name="description" content={description} />
		<!-- Open Graph (also used by Mastodon, BlueSky, etc.) -->
		<meta property="og:title" content="{data.place.name} | Gallformers" />
		<meta property="og:description" content={description} />
		<meta property="og:type" content="website" />
		<meta property="og:url" content="https://gallformers.org/place/{data.place.id}" />
		<meta property="og:image" content="https://gallformers.org/images/place.svg" />
		<meta property="og:site_name" content="Gallformers" />
	{:else}
		<title>Place Not Found | Gallformers</title>
		<meta name="description" content="Place not found on Gallformers." />
	{/if}
</svelte:head>

<div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
	{#if data.error}
		<ErrorMessage message={data.error} />
	{:else if data.place}
		<!-- Header -->
		<div class="mb-6">
			<div class="flex items-center justify-between mb-2">
				<h1 class="text-2xl font-bold text-gf-maroon">
					{data.place.name} - {data.place.code}
				</h1>
				<EditButton id={data.place.id} type="place" />
			</div>

			<!-- Parent info -->
			{#if data.parent}
				<p class="text-gray-600">
					{formatParentInfo(data.place, data.parent)}
				</p>
			{/if}
		</div>

		<!-- Hosts list -->
		<div class="mt-6">
			<h2 class="text-lg font-semibold text-gray-800 mb-3">
				Host Plants ({sortedHosts.length})
			</h2>
			{#if sortedHosts.length > 0}
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
							{#each sortedHosts as host}
								<tr class="hover:bg-gray-50">
									<td class="px-6 py-4 whitespace-nowrap text-sm">
										<a
											href="/host/{host.id}"
											class="text-blue-600 hover:underline"
										>
											<em>{host.name}</em>
										</a>
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{:else}
				<p class="text-gray-500 italic">No host plants found for this location.</p>
			{/if}
		</div>
	{:else}
		<ErrorMessage message="Place not found" />
	{/if}
</div>
