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

<div>
	<!-- Common Names -->
	<div>
		<strong>Common Name(s): </strong>
		<span>
			{#if commonNames.length > 0}
				{commonNames.join(', ')}
			{:else}
				<span class="italic">None</span>
			{/if}
		</span>
	</div>

	<!-- Synonyms -->
	<div>
		<strong>Synonymy: </strong>

		{#if synonyms.length === 0}
			<span class="italic">None</span>
		{:else if showAllByDefault}
			<!-- Always show table when showAllByDefault is true -->
			<div class="mt-1 overflow-x-auto">
				<table class="min-w-full border border-gray-200">
					<thead class="bg-cadet-blue">
						<tr>
							<th class="px-2 py-1 text-left font-medium">Name</th>
							<th class="px-2 py-1 text-left font-medium">Notes</th>
						</tr>
					</thead>
					<tbody class="divide-y divide-gray-200">
						{#each synonyms as synonym, i}
							<tr class="hover:bg-gray-50 {i % 2 === 1 ? 'bg-gray-50' : ''}">
								<td class="px-2 py-1 italic">{synonym.name}</td>
								<td class="px-2 py-1">{synonym.description || ''}</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
		{:else}
			<!-- Collapsed view with toggle -->
			{#if !showSynonyms}
				<span class="truncate block max-w-full overflow-hidden text-ellipsis whitespace-nowrap">
					{synonymsList}
				</span>
			{/if}

			<div class="mt-1">
				<button
					type="button"
					onclick={() => (showSynonyms = !showSynonyms)}
					class="text-sm px-2 py-0.5 border border-gray-300 rounded bg-white hover:bg-gray-50"
				>
					{#if showSynonyms}
						Hide
					{:else}
						Click to see all synonym details.
					{/if}
				</button>

				{#if showSynonyms}
					<div class="mt-1 overflow-x-auto">
						<table class="min-w-full border border-gray-200">
							<thead class="bg-cadet-blue">
								<tr>
									<th class="px-2 py-1 text-left font-medium">Name</th>
									<th class="px-2 py-1 text-left font-medium">Notes</th>
								</tr>
							</thead>
							<tbody class="divide-y divide-gray-200">
								{#each synonyms as synonym, i}
									<tr class="hover:bg-gray-50 {i % 2 === 1 ? 'bg-gray-50' : ''}">
										<td class="px-2 py-1 italic">{synonym.name}</td>
										<td class="px-2 py-1">{synonym.description || ''}</td>
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
