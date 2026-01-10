<script>
	import { Table } from '$lib/components';
	import EditButton from '$lib/components/public/EditButton.svelte';
	import ErrorMessage from '$lib/components/public/ErrorMessage.svelte';

	let { data } = $props();

	/**
	 * Format genus name with description
	 */
	function formatWithDescription(name, description) {
		if (description) {
			return `${name} (${description})`;
		}
		return name;
	}

	/**
	 * Table columns for species list
	 */
	const columns = [
		{
			key: 'name',
			label: 'Species Name',
			sortable: true,
			render: (row) => row.name
		}
	];

	/**
	 * Sorted species list
	 */
	let sortedSpecies = $derived(
		[...(data.species || [])].sort((a, b) => a.name.localeCompare(b.name))
	);
</script>

<svelte:head>
	{#if data.genus}
		<title>{data.genus.name} | Gallformers</title>
		<meta name="description" content="Genus {data.genus.name} - Taxonomy on Gallformers." />
	{:else}
		<title>Genus Not Found | Gallformers</title>
	{/if}
</svelte:head>

<div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
	{#if data.error}
		<ErrorMessage message={data.error} />
	{:else if data.genus}
		<!-- Header -->
		<div class="mb-6">
			<div class="flex items-center justify-between mb-2">
				<h1 class="text-2xl font-bold text-gf-maroon">
					Genus <em>{formatWithDescription(data.genus.name, data.genus.description)}</em>
				</h1>
				<EditButton id={data.genus.id} type="taxonomy" />
			</div>

			<!-- Family link -->
			{#if data.family}
				<div class="text-gray-700">
					<span class="font-semibold">Family:</span>
					<a href="/family/{data.family.id}" class="text-blue-600 hover:underline">
						<em>{data.family.name}</em>
					</a>
					{#if data.family.description}
						<span class="text-gray-600">({data.family.description})</span>
					{/if}
				</div>
			{/if}
		</div>

		<!-- Species list -->
		<div class="mt-6">
			{#if sortedSpecies.length > 0}
				<h2 class="text-lg font-semibold text-gray-800 mb-3">Species ({sortedSpecies.length})</h2>
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
				<p class="text-gray-500 italic">No species found for this genus.</p>
			{/if}
		</div>
	{:else}
		<ErrorMessage message="Genus not found" />
	{/if}
</div>
