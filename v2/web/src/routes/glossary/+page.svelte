<script>
	import { onMount } from 'svelte';
	import EditButton from '$lib/components/public/EditButton.svelte';

	let { data } = $props();

	// Use entries from load function (server-side) with client-side state for sorting
	let entries = $derived(data.entries || []);
	let error = $derived(data.error || null);
	let sortBy = $state('word');
	let sortDir = $state('asc');

	// For cross-linking: build a map of words to their anchors
	let wordMap = $derived(
		entries.reduce((map, entry) => {
			map[entry.word.toLowerCase()] = entry.word;
			return map;
		}, {})
	);

	// Sort entries client-side
	let sortedEntries = $derived(
		[...entries].sort((a, b) => {
			const aVal = a[sortBy] || '';
			const bVal = b[sortBy] || '';
			const cmp = aVal.localeCompare(bVal, undefined, { sensitivity: 'base' });
			return sortDir === 'asc' ? cmp : -cmp;
		})
	);

	// Cross-link glossary terms within definitions
	function linkifyDefinition(definition) {
		if (!definition || entries.length === 0) return definition;

		let result = definition;
		// Sort words by length (longest first) to avoid partial matches
		const words = Object.keys(wordMap).sort((a, b) => b.length - a.length);

		for (const word of words) {
			// Match whole words only, case-insensitive
			const regex = new RegExp(`\\b(${escapeRegex(word)})\\b`, 'gi');
			result = result.replace(regex, (match) => {
				const anchor = wordMap[word.toLowerCase()].toLowerCase();
				return `<a href="#${anchor}" class="text-gf-maroon hover:text-gf-maroon-dark underline">${match}</a>`;
			});
		}
		return result;
	}

	function escapeRegex(string) {
		return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
	}

	// Format reference URLs
	function formatRefs(urls) {
		if (!urls) return [];
		const urlList = urls.split('\n').filter(u => u.trim());
		return urlList.map((url, i) => ({
			url: url.trim(),
			index: i + 1,
			isLast: i === urlList.length - 1
		}));
	}

	function handleSort(key) {
		if (sortBy === key) {
			sortDir = sortDir === 'asc' ? 'desc' : 'asc';
		} else {
			sortBy = key;
			sortDir = 'asc';
		}
	}

	// Handle URL hash for direct term navigation
	function scrollToHash() {
		const hash = window.location.hash.slice(1);
		if (hash) {
			const element = document.getElementById(hash);
			if (element) {
				element.scrollIntoView({ behavior: 'smooth', block: 'start' });
				element.classList.add('bg-yellow-100');
				setTimeout(() => element.classList.remove('bg-yellow-100'), 2000);
			}
		}
	}

	// Use effect to scroll when entries are loaded and there's a hash
	$effect(() => {
		if (entries.length > 0 && typeof window !== 'undefined' && window.location.hash) {
			setTimeout(scrollToHash, 100);
		}
	});

	onMount(() => {
		window.addEventListener('hashchange', scrollToHash);
		return () => window.removeEventListener('hashchange', scrollToHash);
	});
</script>

<svelte:head>
	<title>Glossary - Gallformers</title>
	<meta name="description" content="A Glossary of Gall Related Terminology" />
</svelte:head>

<div class="mx-auto max-w-6xl px-4 py-8 sm:px-6 lg:px-8">
	<h1 class="text-3xl font-bold text-gf-maroon mb-6">A Glossary of Gall Related Terminology</h1>

	{#if error}
		<div class="bg-red-50 border border-red-200 rounded-lg p-4 text-red-700">
			<p>Error loading glossary: {error}</p>
		</div>
	{:else if entries.length === 0}
		<div class="bg-gray-50 rounded-lg p-8 text-center text-gray-600">
			<p>No glossary entries found.</p>
		</div>
	{:else}
		<div class="bg-white rounded-lg shadow overflow-hidden">
			<table class="min-w-full divide-y divide-gray-200">
				<thead class="bg-gray-50">
					<tr>
						<th
							class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100 w-1/4"
							onclick={() => handleSort('word')}
						>
							Word
							{#if sortBy === 'word'}
								<span class="ml-1">{sortDir === 'asc' ? '↑' : '↓'}</span>
							{/if}
						</th>
						<th
							class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
							onclick={() => handleSort('definition')}
						>
							Definition
							{#if sortBy === 'definition'}
								<span class="ml-1">{sortDir === 'asc' ? '↑' : '↓'}</span>
							{/if}
						</th>
						<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider w-24">
							Refs
						</th>
					</tr>
				</thead>
				<tbody class="bg-white divide-y divide-gray-200">
					{#each sortedEntries as entry (entry.id)}
						<tr class="hover:bg-gray-50 transition-colors" id={entry.word.toLowerCase()}>
							<td class="px-6 py-4 text-sm font-medium text-gray-900 align-top">
								<div class="flex items-center gap-2">
									<span class="font-bold">{entry.word}</span>
									<EditButton id={entry.id} type="glossary" isAuthenticated={false} />
								</div>
							</td>
							<td class="px-6 py-4 text-sm text-gray-700 align-top">
								{@html linkifyDefinition(entry.definition)}
							</td>
							<td class="px-6 py-4 text-sm text-gray-500 align-top">
								{#each formatRefs(entry.urls) as ref}
									<a
										href={ref.url}
										target="_blank"
										rel="noreferrer"
										class="text-gf-maroon hover:text-gf-maroon-dark"
									>{ref.index}</a>{#if !ref.isLast}, {/if}
								{/each}
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
		</div>

		<div class="mt-4 text-sm text-gray-500">
			Showing {entries.length} entries
		</div>
	{/if}
</div>
