<script>
	/**
	 * SpeciesSynonymy - Displays species aliases and synonyms
	 *
	 * Shows common names and scientific synonyms for a species.
	 * Scientific synonyms can be expanded to show a table with notes.
	 *
	 * @typedef {Object} Alias
	 * @property {number} id - Alias ID
	 * @property {string} name - Alias name
	 * @property {string} type - 'common' or 'scientific'
	 * @property {string} [description] - Notes about the alias
	 */

	let { aliases = [], showAllByDefault = false } = $props();

	// Track whether synonyms are expanded - reset when showAllByDefault prop changes
	let showSynonyms = $state(false);

	$effect(() => {
		showSynonyms = showAllByDefault;
	});

	// Filter aliases by type
	let commonNames = $derived(
		aliases
			.filter((a) => a.type === 'common')
			.map((a) => a.name)
			.sort()
	);

	let synonyms = $derived(aliases.filter((a) => a.type === 'scientific').sort((a, b) => a.name.localeCompare(b.name)));

	// Collapsed display text
	let synonymsList = $derived(synonyms.map((s) => s.name).join(', '));
</script>

<div class="space-y-2">
	<!-- Common Names -->
	<div>
		<span class="font-semibold">Common Name(s): </span>
		<span class="text-gray-700">
			{#if commonNames.length > 0}
				{commonNames.join(', ')}
			{:else}
				<span class="text-gray-400 italic">None</span>
			{/if}
		</span>
	</div>

	<!-- Synonyms -->
	<div>
		<span class="font-semibold">Synonymy: </span>

		{#if synonyms.length === 0}
			<span class="text-gray-400 italic">None</span>
		{:else if showAllByDefault}
			<!-- Always show table when showAllByDefault is true -->
			<div class="mt-2 overflow-x-auto">
				<table class="min-w-full text-sm border border-gray-200">
					<thead class="bg-gray-50">
						<tr>
							<th class="px-3 py-2 text-left font-medium text-gray-700">Name</th>
							<th class="px-3 py-2 text-left font-medium text-gray-700">Notes</th>
						</tr>
					</thead>
					<tbody class="divide-y divide-gray-100">
						{#each synonyms as synonym}
							<tr class="hover:bg-gray-50">
								<td class="px-3 py-2 italic">{synonym.name}</td>
								<td class="px-3 py-2 text-gray-600">{synonym.description || ''}</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
		{:else}
			<!-- Collapsed view with toggle -->
			{#if !showSynonyms}
				<span class="text-gray-700 truncate block max-w-full overflow-hidden text-ellipsis whitespace-nowrap">
					{synonymsList}
				</span>
			{/if}

			<div class="mt-1">
				<button
					type="button"
					onclick={() => (showSynonyms = !showSynonyms)}
					class="text-sm px-3 py-1 border border-gray-300 rounded-md bg-white hover:bg-gray-50 text-gray-700 transition-colors"
				>
					{#if showSynonyms}
						Hide
					{:else}
						Click to see all synonym details.
					{/if}
				</button>

				{#if showSynonyms}
					<div class="mt-2 overflow-x-auto">
						<table class="min-w-full text-sm border border-gray-200">
							<thead class="bg-gray-50">
								<tr>
									<th class="px-3 py-2 text-left font-medium text-gray-700">Name</th>
									<th class="px-3 py-2 text-left font-medium text-gray-700">Notes</th>
								</tr>
							</thead>
							<tbody class="divide-y divide-gray-100">
								{#each synonyms as synonym}
									<tr class="hover:bg-gray-50">
										<td class="px-3 py-2 italic">{synonym.name}</td>
										<td class="px-3 py-2 text-gray-600">{synonym.description || ''}</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				{/if}
			</div>
		{/if}
	</div>
</div>
