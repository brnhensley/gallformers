<script>
	import { goto } from '$app/navigation';
	import { Input } from '$lib/components';

	let { data } = $props();

	// Local state for input that syncs with data.query when it changes
	let searchInput = $state('');

	// Sync searchInput with data.query when data changes (e.g., navigation)
	$effect(() => {
		searchInput = data.query;
	});

	// Debounced search handler
	let searchTimeout;
	function handleSearchInput(event) {
		searchInput = event.target.value;
		clearTimeout(searchTimeout);
		searchTimeout = setTimeout(() => {
			const query = searchInput.trim();
			if (query) {
				goto(`/globalsearch?q=${encodeURIComponent(query)}`, { keepFocus: true });
			} else {
				goto('/globalsearch', { keepFocus: true });
			}
		}, 300);
	}

	// Handle form submission
	function handleSubmit(event) {
		event.preventDefault();
		clearTimeout(searchTimeout);
		const query = searchInput.trim();
		if (query) {
			goto(`/globalsearch?q=${encodeURIComponent(query)}`);
		}
	}

	// Get icon for result type
	function getTypeIcon(type) {
		switch (type) {
			case 'gall':
				return '/images/cynipid_R.svg';
			case 'plant':
				return '/images/host.svg';
			case 'entry':
				return '/images/entry.svg';
			case 'source':
				return '/images/source.svg';
			case 'genus':
			case 'section':
			case 'family':
				return '/images/taxon.svg';
			case 'place':
				return '/images/place.svg';
			default:
				return null;
		}
	}

	// Get icon size for result type
	function getTypeIconSize(type) {
		return type === 'gall' ? 45 : 25;
	}

	// Get link for result
	function getResultLink(item) {
		switch (item.type) {
			case 'gall':
				return `/gall/${item.id}`;
			case 'plant':
				return `/host/${item.id}`;
			case 'entry':
				return `/glossary#${item.name.toLowerCase()}`;
			case 'source':
				return `/source/${item.id}`;
			case 'genus':
				return `/genus/${item.id}`;
			case 'section':
				return `/section/${item.id}`;
			case 'family':
				return `/family/${item.id}`;
			case 'place':
				return `/place/${item.id}`;
			default:
				return '#';
		}
	}

	// Format name with aliases
	function formatName(item) {
		if (item.aliases && item.aliases.length > 0) {
			return `${item.name} (${item.aliases.join(', ')})`;
		}
		return item.name;
	}

	// Get display name with type prefix for taxonomy entries
	function getDisplayName(item) {
		const name = formatName(item);
		switch (item.type) {
			case 'genus':
				return `Genus ${name}`;
			case 'section':
				return `Section ${name}`;
			case 'family':
				return `Family ${name}`;
			default:
				return name;
		}
	}

	// Should name be italicized
	function shouldItalicize(type) {
		return ['gall', 'plant', 'genus', 'section'].includes(type);
	}

	// Sort state
	let sortBy = $state('name');
	let sortDir = $state('asc');

	// Sorted results
	let sortedResults = $derived.by(() => {
		if (!data.results || data.results.length === 0) return [];

		const sorted = [...data.results];
		sorted.sort((a, b) => {
			let aVal, bVal;
			if (sortBy === 'type') {
				aVal = a.type;
				bVal = b.type;
			} else {
				aVal = a.name.toLowerCase();
				bVal = b.name.toLowerCase();
			}

			if (aVal < bVal) return sortDir === 'asc' ? -1 : 1;
			if (aVal > bVal) return sortDir === 'asc' ? 1 : -1;
			return 0;
		});
		return sorted;
	});

	function handleSort(column) {
		if (sortBy === column) {
			sortDir = sortDir === 'asc' ? 'desc' : 'asc';
		} else {
			sortBy = column;
			sortDir = 'asc';
		}
	}
</script>

<svelte:head>
	<title>Search Results - '{data.query}' | Gallformers</title>
	<meta name="description" content="Gallformers Search Results" />
</svelte:head>

<div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
	<h1 class="text-2xl font-bold text-gf-maroon mb-6">Search Gallformers</h1>

	<!-- Search input -->
	<form onsubmit={handleSubmit} class="mb-6">
		<div class="max-w-xl">
			<Input
				type="search"
				placeholder="Search for galls, hosts, sources, glossary terms..."
				value={searchInput}
				oninput={handleSearchInput}
			/>
		</div>
	</form>

	<!-- Results -->
	{#if data.error}
		<div class="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded">
			<p>{data.error}</p>
		</div>
	{:else if !data.query}
		<div class="text-gray-600">
			<p>Enter a search term to find galls, hosts, sources, glossary entries, and more.</p>
		</div>
	{:else if data.results.length === 0}
		<div class="bg-gray-50 border border-gray-200 px-4 py-3 rounded">
			<p class="font-medium">No results for '{data.query}'</p>
			<p class="text-sm text-gray-600 mt-1">Try adjusting your search terms.</p>
		</div>
	{:else}
		<p class="text-sm text-gray-600 mb-4">
			Found {data.results.length} result{data.results.length === 1 ? '' : 's'} for '{data.query}'
		</p>

		<div class="overflow-x-auto">
			<table class="min-w-full divide-y divide-gray-200">
				<thead class="bg-gray-50">
					<tr>
						<th
							class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100 w-24"
							onclick={() => handleSort('type')}
						>
							Type
							{#if sortBy === 'type'}
								<span class="ml-1">{sortDir === 'asc' ? '↑' : '↓'}</span>
							{/if}
						</th>
						<th
							class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
							onclick={() => handleSort('name')}
						>
							Name
							{#if sortBy === 'name'}
								<span class="ml-1">{sortDir === 'asc' ? '↑' : '↓'}</span>
							{/if}
						</th>
					</tr>
				</thead>
				<tbody class="bg-white divide-y divide-gray-200">
					{#each sortedResults as result (result.uid)}
						<tr class="hover:bg-gray-50">
							<td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 text-center">
								{#if getTypeIcon(result.type)}
									<img
										src={getTypeIcon(result.type)}
										alt={result.type}
										width={getTypeIconSize(result.type)}
										height={getTypeIconSize(result.type)}
										class="inline-block"
									/>
								{/if}
							</td>
							<td class="px-6 py-4 text-sm text-gray-900">
								<a
									href={getResultLink(result)}
									class="text-gf-maroon hover:text-gf-maroon-dark hover:underline"
								>
									{#if shouldItalicize(result.type)}
										<em>{getDisplayName(result)}</em>
									{:else}
										{getDisplayName(result)}
									{/if}
								</a>
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
		</div>
	{/if}
</div>
