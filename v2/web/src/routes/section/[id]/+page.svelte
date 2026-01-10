<script>
	import EditButton from '$lib/components/public/EditButton.svelte';
	import ErrorMessage from '$lib/components/public/ErrorMessage.svelte';

	let { data } = $props();

	/**
	 * Format name with description
	 */
	function formatFullName(name, description) {
		if (description) {
			return `${name} (${description})`;
		}
		return name;
	}

	/**
	 * Sorted species list
	 */
	let sortedSpecies = $derived(
		[...(data.species || [])].sort((a, b) => a.name.localeCompare(b.name))
	);
</script>

<svelte:head>
	{#if data.section}
		<title>{data.section.name} | Gallformers</title>
		<meta name="description" content="Section {formatFullName(data.section.name, data.section.description)} - Taxonomy on Gallformers." />
	{:else}
		<title>Section Not Found | Gallformers</title>
	{/if}
</svelte:head>

<div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
	{#if data.error}
		<ErrorMessage message={data.error} />
	{:else if data.section}
		<!-- Header -->
		<div class="mb-6">
			<div class="flex items-center justify-between mb-2">
				<h1 class="text-2xl font-bold text-gf-maroon">
					{formatFullName(data.section.name, data.section.description)}
				</h1>
				<EditButton id={data.section.id} type="section" />
			</div>
		</div>

		<!-- Species list -->
		<div class="mt-6">
			<h2 class="text-lg font-semibold text-gray-800 mb-3">
				Species ({sortedSpecies.length})
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
								<tr class="hover:bg-gray-50">
									<td class="px-6 py-4 whitespace-nowrap text-sm">
										<!-- Sections are for hosts (plants) -->
										<a
											href="/host/{species.id}"
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
				<p class="text-gray-500 italic">No species found for this section.</p>
			{/if}
		</div>
	{:else}
		<ErrorMessage message="Section not found" />
	{/if}
</div>
