<script>
	/**
	 * SourceList - Citation list with selection state
	 *
	 * Displays a list of sources/citations for a species with:
	 * - Selectable rows that display description content
	 * - Navigation between sources
	 * - License icons
	 * - Links to source detail pages
	 *
	 * @typedef {Object} Source
	 * @property {number} id - Source ID
	 * @property {string} title - Source title
	 * @property {string} author - Author name(s)
	 * @property {string} pubyear - Publication year
	 * @property {string} [license] - License type
	 * @property {string} [licenseLink] - URL to license
	 *
	 * @typedef {Object} SpeciesSource
	 * @property {number} id - Species-source relation ID
	 * @property {number} sourceId - Source ID
	 * @property {Source} source - Source details
	 * @property {string} [description] - Description text from this source
	 * @property {string} [externalLink] - External reference URL
	 */

	let {
		sources = [],
		selectedId = $bindable(null),
		onselect,
		showGallformersNotes = true,
		gallformersNotesId = 58
	} = $props();

	// Find gallformers notes if present
	let gallformersNotes = $derived(sources.find((s) => s.source?.id === gallformersNotesId));
	let showNotesAlert = $state(true);

	// Sort sources by publication year
	let sortedSources = $derived(
		[...sources].sort((a, b) => parseInt(a.source?.pubyear || '0') - parseInt(b.source?.pubyear || '0'))
	);

	// Currently selected source
	let selectedSource = $derived(sources.find((s) => s.source?.id === selectedId) || sources[0]);

	function selectSource(source) {
		if (source?.source?.id !== selectedId) {
			selectedId = source?.source?.id;
			if (onselect) {
				onselect(source);
			}
		}
	}

	function selectPrev() {
		const currentIdx = sortedSources.findIndex((s) => s.source?.id === selectedId);
		const newIdx = (currentIdx - 1 + sortedSources.length) % sortedSources.length;
		selectSource(sortedSources[newIdx]);
	}

	function selectNext() {
		const currentIdx = sortedSources.findIndex((s) => s.source?.id === selectedId);
		const newIdx = (currentIdx + 1) % sortedSources.length;
		selectSource(sortedSources[newIdx]);
	}

	function dismissNotesAlert() {
		showNotesAlert = false;
	}

	function selectGallformersNotes() {
		selectSource(gallformersNotes);
	}

	function getLicenseIcon(license) {
		switch (license) {
			case 'Public Domain':
				return '/images/CC0.png';
			case 'CC BY':
				return '/images/CCBY.png';
			case 'All Rights Reserved':
				return '/images/allrights.svg';
			default:
				return null;
		}
	}

	function formatSourceDisplay(source) {
		if (!source) return '';
		const parts = [source.author];
		if (source.pubyear) {
			parts.push(`(${source.pubyear})`);
		}
		return parts.join(' ');
	}
</script>

<div class="space-y-4">
	<!-- Notes Alert -->
	{#if showGallformersNotes && showNotesAlert && gallformersNotes && selectedId !== gallformersNotes.source?.id}
		<div class="bg-blue-50 border border-blue-200 rounded-md p-4 flex items-start justify-between">
			<div class="flex-1">
				<p class="text-sm text-blue-800">
					Our ID Notes may contain important tips necessary for distinguishing this gall from similar
					galls and/or important information about the taxonomic status of this gall inducer.
				</p>
			</div>
			<div class="flex items-center gap-2 ml-4">
				<button
					type="button"
					onclick={selectGallformersNotes}
					class="text-sm bg-blue-100 hover:bg-blue-200 text-blue-800 px-3 py-1 rounded transition-colors"
				>
					Show notes
				</button>
				<button
					type="button"
					onclick={dismissNotesAlert}
					class="text-blue-400 hover:text-blue-600"
					aria-label="Dismiss"
				>
					<svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
					</svg>
				</button>
			</div>
		</div>
	{/if}

	<!-- Selected Source Header -->
	<div class="flex items-center justify-between">
		<div class="flex-1">
			{#if selectedSource}
				<em class="text-gray-700">
					<a href="/source/{selectedSource.source?.id}" class="text-blue-600 hover:underline">
						{selectedSource.source?.title}
					</a>
				</em>
			{/if}
		</div>
		{#if sources.length > 1}
			<div class="flex gap-1">
				<button
					type="button"
					onclick={selectPrev}
					class="px-3 py-1 text-sm bg-gray-200 hover:bg-gray-300 rounded transition-colors"
					aria-label="Select previous source"
				>
					&lt;
				</button>
				<button
					type="button"
					onclick={selectNext}
					class="px-3 py-1 text-sm bg-gray-200 hover:bg-gray-300 rounded transition-colors"
					aria-label="Select next source"
				>
					&gt;
				</button>
			</div>
		{/if}
	</div>

	<!-- Description Content -->
	{#if selectedSource?.description}
		<div class="text-lg text-gray-700 p-4 bg-gray-50 rounded-md">
			<span class="text-gray-400 text-2xl leading-none">&ldquo;</span>
			<span class="whitespace-pre-wrap">{@html selectedSource.description}</span>
			<span class="text-gray-400 text-2xl leading-none">&rdquo;</span>
			<p class="mt-4 text-sm text-gray-600 italic">
				- {formatSourceDisplay(selectedSource.source)}
			</p>
			{#if selectedSource.externalLink}
				<p class="mt-2 text-sm">
					Reference:
					<a
						href={selectedSource.externalLink}
						target="_blank"
						rel="noreferrer"
						class="text-blue-600 hover:underline break-all"
					>
						{selectedSource.externalLink}
					</a>
				</p>
			{/if}
		</div>
	{/if}

	<hr class="border-gray-200" />

	<!-- Sources Table -->
	<div>
		<h4 class="font-semibold text-gray-700 mb-2">Further Information:</h4>
		<div class="overflow-x-auto">
			<table class="min-w-full text-sm">
				<thead class="sr-only">
					<tr>
						<th>Author</th>
						<th>Year</th>
						<th>Title</th>
						<th>License</th>
					</tr>
				</thead>
				<tbody class="divide-y divide-gray-100">
					{#each sortedSources as speciesSource}
						<tr
							class="cursor-pointer transition-colors {speciesSource.source?.id === selectedId
								? 'bg-blue-50 border-l-4 border-blue-500'
								: 'hover:bg-gray-50'}"
							onclick={() => selectSource(speciesSource)}
						>
							<td class="py-2 px-3 max-w-[200px]">
								<span class="line-clamp-2">{speciesSource.source?.author || 'Unknown'}</span>
							</td>
							<td class="py-2 px-3 text-center hidden sm:table-cell">
								{speciesSource.source?.pubyear || ''}
							</td>
							<td class="py-2 px-3">
								<a
									href="/source/{speciesSource.source?.id}"
									class="text-blue-600 hover:underline line-clamp-2"
									onclick={(e) => e.stopPropagation()}
								>
									{speciesSource.source?.title || 'Untitled'}
								</a>
							</td>
							<td class="py-2 px-3 text-center hidden sm:table-cell">
								{#if speciesSource.source?.license}
									{@const icon = getLicenseIcon(speciesSource.source.license)}
									{#if icon}
										<a
											href={speciesSource.source.licenseLink || 'https://creativecommons.org/publicdomain/mark/1.0/'}
											target="_blank"
											rel="noreferrer"
											onclick={(e) => e.stopPropagation()}
										>
											<img src={icon} alt={speciesSource.source.license} class="h-5 inline-block" />
										</a>
									{/if}
								{/if}
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
		</div>
	</div>
</div>
