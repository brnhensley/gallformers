<script>
	import { goto } from '$app/navigation';
	import TreeMenu from '$lib/components/public/TreeMenu.svelte';
	import EditButton from '$lib/components/public/EditButton.svelte';
	import ErrorMessage from '$lib/components/public/ErrorMessage.svelte';

	let { data } = $props();

	// Track expanded nodes - reset when data changes (e.g., navigating to different family)
	let expandedKeys = $state(new Set());

	$effect(() => {
		expandedKeys = data.initialExpandedKeys || new Set();
	});

	/**
	 * Handle tree item click - navigate to species page
	 */
	function handleItemClick(item) {
		if (item.url) {
			goto(item.url);
		}
	}
</script>

<svelte:head>
	{#if data.family}
		{@const description = `Family ${data.family.name}${data.family.description ? ` - ${data.family.description}` : ''} - Taxonomy on Gallformers.`}
		<title>{data.family.name} | Gallformers</title>
		<meta name="description" content={description} />
		<!-- Open Graph (also used by Mastodon, BlueSky, etc.) -->
		<meta property="og:title" content="Family {data.family.name} | Gallformers" />
		<meta property="og:description" content={description} />
		<meta property="og:type" content="website" />
		<meta property="og:url" content="https://gallformers.org/family/{data.family.id}" />
		<meta property="og:image" content="https://gallformers.org/images/taxon.svg" />
		<meta property="og:site_name" content="Gallformers" />
	{:else}
		<title>Family Not Found | Gallformers</title>
		<meta name="description" content="Family not found on Gallformers." />
	{/if}
</svelte:head>

<div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
	{#if data.error}
		<ErrorMessage message={data.error} />
	{:else if data.family}
		<!-- Header -->
		<div class="bg-white rounded border border-gray-200 shadow-sm">
			<div class="px-4 py-3 border-b border-gray-200">
				<div class="flex items-center justify-between">
					<h1 class="text-2xl font-bold text-gf-maroon">
						{data.family.name}
						{#if data.family.description}
							<span class="text-lg font-normal text-gray-600">
								- {data.family.description}
							</span>
						{/if}
					</h1>
					<EditButton id={data.family.id} type="taxonomy" />
				</div>
			</div>
			<div class="p-4">
				{#if data.treeData && data.treeData.length > 0}
					<TreeMenu
						data={data.treeData}
						onitemclick={handleItemClick}
						bind:expandedKeys
					/>
				{:else}
					<p class="text-gray-500 italic">No genera or species found for this family.</p>
				{/if}
			</div>
		</div>
	{:else}
		<ErrorMessage message="Family not found" />
	{/if}
</div>
