<script>
	import { goto } from '$app/navigation';
	import TreeMenu from '$lib/components/public/TreeMenu.svelte';
	import Tabs from '$lib/components/public/Tabs.svelte';

	let { data } = $props();

	// Tab definitions
	const tabs = [
		{ key: 'galls', label: 'Galls' },
		{ key: 'undescribed', label: 'Undescribed Galls' },
		{ key: 'hosts', label: 'Hosts' }
	];

	// Active tab state
	let activeKey = $state('galls');

	// Separate expanded state for each tree to prevent state leakage
	let gallsExpanded = $state(new Set());
	let undescribedExpanded = $state(new Set());
	let hostsExpanded = $state(new Set());

	// Handle tree item click - navigate to species page
	function handleItemClick(item) {
		if (item.url) {
			goto(item.url);
		}
	}
</script>

<svelte:head>
	<title>Explore Galls & Hosts | Gallformers</title>
	<meta name="description" content="Browse all of the galls and hosts that Gallformers has in its database." />
	<!-- Open Graph (also used by Mastodon, BlueSky, etc.) -->
	<meta property="og:title" content="Explore Galls & Hosts | Gallformers" />
	<meta property="og:description" content="Browse all of the galls and hosts that Gallformers has in its database." />
	<meta property="og:type" content="website" />
	<meta property="og:url" content="https://gallformers.org/explore" />
	<meta property="og:image" content="https://gallformers.org/images/cynipid_R.svg" />
	<meta property="og:site_name" content="Gallformers" />
</svelte:head>

<div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
	<h1 class="text-2xl font-bold text-gf-maroon mb-6">Explore Galls & Hosts</h1>

	{#if data.error}
		<div class="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded">
			<p>{data.error}</p>
		</div>
	{:else}
		<div class="bg-white rounded border border-gray-200 shadow-sm">
			<Tabs {tabs} bind:activeKey>
				{#snippet content(key)}
					{#if key === 'galls'}
						<div class="px-4 pb-4">
							<h2 class="text-lg font-semibold text-gf-maroon mb-3">Browse Galls - By Family</h2>
							{#if data.galls.length === 0}
								<p class="text-gray-500">No gall data available.</p>
							{:else}
								<TreeMenu
									data={data.galls}
									onitemclick={handleItemClick}
									bind:expandedKeys={gallsExpanded}
								/>
							{/if}
						</div>
					{:else if key === 'undescribed'}
						<div class="px-4 pb-4">
							<h2 class="text-lg font-semibold text-gf-maroon mb-3">Browse Undescribed Galls</h2>
							{#if data.undescribed.length === 0}
								<p class="text-gray-500">No undescribed galls available.</p>
							{:else}
								<TreeMenu
									data={data.undescribed}
									onitemclick={handleItemClick}
									bind:expandedKeys={undescribedExpanded}
								/>
							{/if}
						</div>
					{:else if key === 'hosts'}
						<div class="px-4 pb-4">
							<h2 class="text-lg font-semibold text-gf-maroon mb-3">Browse Hosts - By Family</h2>
							{#if data.hosts.length === 0}
								<p class="text-gray-500">No host data available.</p>
							{:else}
								<TreeMenu
									data={data.hosts}
									onitemclick={handleItemClick}
									bind:expandedKeys={hostsExpanded}
								/>
							{/if}
						</div>
					{/if}
				{/snippet}
			</Tabs>
		</div>
	{/if}
</div>
