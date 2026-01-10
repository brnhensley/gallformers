<script>
	import { onMount } from 'svelte';

	let filterFields = $state({
		alignment: [],
		cells: [],
		form: [],
		location: [],
		shape: [],
		texture: [],
		walls: []
	});
	let loading = $state(true);
	let error = $state(null);
	let openSections = $state({});

	const filterTypes = [
		{ key: 'alignment', label: 'Alignment' },
		{ key: 'cells', label: 'Cells' },
		{ key: 'form', label: 'Forms' },
		{ key: 'location', label: 'Location' },
		{ key: 'shape', label: 'Shape' },
		{ key: 'texture', label: 'Texture' },
		{ key: 'walls', label: 'Walls' }
	];

	onMount(async () => {
		try {
			const responses = await Promise.all(
				filterTypes.map(type =>
					fetch(`/api/v2/filter-fields/${type.key}`).then(r => r.json())
				)
			);

			filterTypes.forEach((type, i) => {
				filterFields[type.key] = responses[i] || [];
			});
		} catch (err) {
			error = err.message;
		} finally {
			loading = false;
		}
	});

	function toggleSection(key) {
		openSections[key] = !openSections[key];
	}

	function sortByField(items) {
		return [...items].sort((a, b) => a.field.localeCompare(b.field));
	}
</script>

<svelte:head>
	<title>Filter Guide | Gallformers</title>
	<meta name="description" content="A guide to all of the terms used on the Gallformers ID page." />
	<!-- Open Graph (also used by Mastodon, BlueSky, etc.) -->
	<meta property="og:title" content="Filter Guide | Gallformers" />
	<meta property="og:description" content="A guide to all of the terms used on the Gallformers ID page." />
	<meta property="og:type" content="website" />
	<meta property="og:url" content="https://gallformers.org/filterguide" />
	<meta property="og:image" content="https://gallformers.org/images/cynipid_R.svg" />
	<meta property="og:site_name" content="Gallformers" />
</svelte:head>

<div class="mx-auto max-w-4xl px-4 py-8 sm:px-6 lg:px-8">
	<h1 class="text-3xl font-bold text-gf-maroon mb-4">ID Tool Filter Guide</h1>
	<p class="text-gray-600 mb-8">
		This guide explains the filter terms used in our gall identification tool. Click on each section to expand and see the definitions.
	</p>

	{#if loading}
		<div class="text-center py-12">
			<div class="animate-spin rounded-full h-12 w-12 border-b-2 border-gf-maroon mx-auto"></div>
			<p class="mt-4 text-gray-600">Loading filter terms...</p>
		</div>
	{:else if error}
		<div class="bg-red-50 border border-red-200 rounded-lg p-4 text-red-700">
			<p>Error loading filter fields: {error}</p>
		</div>
	{:else}
		<div class="space-y-4">
			<!-- Alignment -->
			<div class="bg-white rounded-lg shadow-md overflow-hidden">
				<button
					onclick={() => toggleSection('alignment')}
					class="w-full px-4 py-3 text-left bg-gray-50 hover:bg-gray-100 flex justify-between items-center"
				>
					<span class="font-semibold text-gray-800">Alignment</span>
					<svg
						class="w-5 h-5 text-gray-500 transition-transform {openSections.alignment ? 'rotate-180' : ''}"
						fill="none"
						stroke="currentColor"
						viewBox="0 0 24 24"
					>
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
					</svg>
				</button>
				{#if openSections.alignment}
					<div class="p-4 border-t">
						<ul class="space-y-2">
							{#each sortByField(filterFields.alignment) as item}
								<li class="text-gray-700">
									<span class="font-medium">{item.field}</span>
									{#if item.description}
										<span> - {item.description}</span>
									{/if}
								</li>
							{/each}
						</ul>
					</div>
				{/if}
			</div>

			<!-- Cells -->
			<div class="bg-white rounded-lg shadow-md overflow-hidden">
				<button
					onclick={() => toggleSection('cells')}
					class="w-full px-4 py-3 text-left bg-gray-50 hover:bg-gray-100 flex justify-between items-center"
				>
					<span class="font-semibold text-gray-800">Cells</span>
					<svg
						class="w-5 h-5 text-gray-500 transition-transform {openSections.cells ? 'rotate-180' : ''}"
						fill="none"
						stroke="currentColor"
						viewBox="0 0 24 24"
					>
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
					</svg>
				</button>
				{#if openSections.cells}
					<div class="p-4 border-t">
						<ul class="space-y-2">
							{#each sortByField(filterFields.cells) as item}
								<li class="text-gray-700">
									<span class="font-medium">{item.field}</span>
									{#if item.description}
										<span> - {item.description}</span>
									{/if}
								</li>
							{/each}
						</ul>
						<p class="mt-4 text-sm text-gray-600 italic">
							NOTE: If multiple larvae are found in one space, these may be
							<a href="/glossary#inquiline" class="text-gf-maroon hover:text-gf-maroon-dark">inquilines</a>
							rather than gall-inducers.
						</p>
					</div>
				{/if}
			</div>

			<!-- Detachable (hardcoded as it's not a filter-field type) -->
			<div class="bg-white rounded-lg shadow-md overflow-hidden">
				<button
					onclick={() => toggleSection('detachable')}
					class="w-full px-4 py-3 text-left bg-gray-50 hover:bg-gray-100 flex justify-between items-center"
				>
					<span class="font-semibold text-gray-800">Detachable</span>
					<svg
						class="w-5 h-5 text-gray-500 transition-transform {openSections.detachable ? 'rotate-180' : ''}"
						fill="none"
						stroke="currentColor"
						viewBox="0 0 24 24"
					>
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
					</svg>
				</button>
				{#if openSections.detachable}
					<div class="p-4 border-t">
						<ul class="space-y-2">
							<li class="text-gray-700">
								<span class="font-medium">Yes</span> - the gall could be removed from the plant without destroying the tissue it's attached to (detachable).
							</li>
							<li class="text-gray-700">
								<span class="font-medium">No</span> - the gall could only be removed from the plant by destroying the tissue it's attached to (integral).
							</li>
						</ul>
						<p class="mt-4 text-sm text-gray-600 italic">
							NOTE: Galls that have detachable parts but leave some galled tissue behind (more than a scar
							or blister), are only detachable in some parts of the season, or may be detachable or not, are
							included in both terms.
						</p>
					</div>
				{/if}
			</div>

			<!-- Forms -->
			<div class="bg-white rounded-lg shadow-md overflow-hidden">
				<button
					onclick={() => toggleSection('form')}
					class="w-full px-4 py-3 text-left bg-gray-50 hover:bg-gray-100 flex justify-between items-center"
				>
					<span class="font-semibold text-gray-800">Forms</span>
					<svg
						class="w-5 h-5 text-gray-500 transition-transform {openSections.form ? 'rotate-180' : ''}"
						fill="none"
						stroke="currentColor"
						viewBox="0 0 24 24"
					>
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
					</svg>
				</button>
				{#if openSections.form}
					<div class="p-4 border-t">
						<ul class="space-y-2">
							{#each sortByField(filterFields.form) as item}
								<li class="text-gray-700">
									<span class="font-medium">{item.field}</span>
									{#if item.description}
										<span> - {item.description}</span>
									{/if}
								</li>
							{/each}
						</ul>
					</div>
				{/if}
			</div>

			<!-- Location -->
			<div class="bg-white rounded-lg shadow-md overflow-hidden">
				<button
					onclick={() => toggleSection('location')}
					class="w-full px-4 py-3 text-left bg-gray-50 hover:bg-gray-100 flex justify-between items-center"
				>
					<span class="font-semibold text-gray-800">Location</span>
					<svg
						class="w-5 h-5 text-gray-500 transition-transform {openSections.location ? 'rotate-180' : ''}"
						fill="none"
						stroke="currentColor"
						viewBox="0 0 24 24"
					>
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
					</svg>
				</button>
				{#if openSections.location}
					<div class="p-4 border-t">
						<ul class="space-y-2">
							{#each sortByField(filterFields.location) as item}
								<li class="text-gray-700">
									<span class="font-medium">{item.field}</span>
									{#if item.description}
										<span> - {item.description}</span>
									{/if}
								</li>
							{/each}
						</ul>
					</div>
				{/if}
			</div>

			<!-- Shape -->
			<div class="bg-white rounded-lg shadow-md overflow-hidden">
				<button
					onclick={() => toggleSection('shape')}
					class="w-full px-4 py-3 text-left bg-gray-50 hover:bg-gray-100 flex justify-between items-center"
				>
					<span class="font-semibold text-gray-800">Shape</span>
					<svg
						class="w-5 h-5 text-gray-500 transition-transform {openSections.shape ? 'rotate-180' : ''}"
						fill="none"
						stroke="currentColor"
						viewBox="0 0 24 24"
					>
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
					</svg>
				</button>
				{#if openSections.shape}
					<div class="p-4 border-t">
						<ul class="space-y-2">
							{#each sortByField(filterFields.shape) as item}
								<li class="text-gray-700">
									<span class="font-medium">{item.field}</span>
									{#if item.description}
										<span> - {item.description}</span>
									{/if}
								</li>
							{/each}
						</ul>
					</div>
				{/if}
			</div>

			<!-- Texture -->
			<div class="bg-white rounded-lg shadow-md overflow-hidden">
				<button
					onclick={() => toggleSection('texture')}
					class="w-full px-4 py-3 text-left bg-gray-50 hover:bg-gray-100 flex justify-between items-center"
				>
					<span class="font-semibold text-gray-800">Texture</span>
					<svg
						class="w-5 h-5 text-gray-500 transition-transform {openSections.texture ? 'rotate-180' : ''}"
						fill="none"
						stroke="currentColor"
						viewBox="0 0 24 24"
					>
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
					</svg>
				</button>
				{#if openSections.texture}
					<div class="p-4 border-t">
						<ul class="space-y-2">
							{#each sortByField(filterFields.texture) as item}
								<li class="text-gray-700">
									<span class="font-medium">{item.field}</span>
									{#if item.description}
										<span> - {item.description}</span>
									{/if}
								</li>
							{/each}
						</ul>
					</div>
				{/if}
			</div>

			<!-- Walls -->
			<div class="bg-white rounded-lg shadow-md overflow-hidden">
				<button
					onclick={() => toggleSection('walls')}
					class="w-full px-4 py-3 text-left bg-gray-50 hover:bg-gray-100 flex justify-between items-center"
				>
					<span class="font-semibold text-gray-800">Walls</span>
					<svg
						class="w-5 h-5 text-gray-500 transition-transform {openSections.walls ? 'rotate-180' : ''}"
						fill="none"
						stroke="currentColor"
						viewBox="0 0 24 24"
					>
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
					</svg>
				</button>
				{#if openSections.walls}
					<div class="p-4 border-t">
						<ul class="space-y-2">
							{#each sortByField(filterFields.walls) as item}
								<li class="text-gray-700">
									<span class="font-medium">{item.field}</span>
									{#if item.description}
										<span> - {item.description}</span>
									{/if}
								</li>
							{/each}
						</ul>
					</div>
				{/if}
			</div>
		</div>
	{/if}
</div>
