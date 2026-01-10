<script>
	/**
	 * Tabs - Tab navigation component
	 *
	 * Provides accessible tab navigation with keyboard support.
	 * Content for each tab is rendered via snippet.
	 *
	 * @typedef {Object} Tab
	 * @property {string} key - Unique tab identifier
	 * @property {string} label - Display label for the tab
	 *
	 * Usage:
	 * <Tabs {tabs} bind:activeKey>
	 *   {#snippet content(key)}
	 *     {#if key === 'tab1'}
	 *       <Tab1Content />
	 *     {:else if key === 'tab2'}
	 *       <Tab2Content />
	 *     {/if}
	 *   {/snippet}
	 * </Tabs>
	 */

	let { tabs = [], activeKey = $bindable(), content } = $props();

	// Set initial active key if not provided
	$effect(() => {
		if (!activeKey && tabs.length > 0) {
			activeKey = tabs[0].key;
		}
	});

	function selectTab(key) {
		activeKey = key;
	}

	function handleKeydown(e, index) {
		let newIndex = index;

		switch (e.key) {
			case 'ArrowLeft':
				e.preventDefault();
				newIndex = index > 0 ? index - 1 : tabs.length - 1;
				break;
			case 'ArrowRight':
				e.preventDefault();
				newIndex = index < tabs.length - 1 ? index + 1 : 0;
				break;
			case 'Home':
				e.preventDefault();
				newIndex = 0;
				break;
			case 'End':
				e.preventDefault();
				newIndex = tabs.length - 1;
				break;
			default:
				return;
		}

		activeKey = tabs[newIndex].key;
		// Focus the new tab button
		const tabButtons = e.currentTarget.parentElement?.querySelectorAll('[role="tab"]');
		if (tabButtons?.[newIndex]) {
			tabButtons[newIndex].focus();
		}
	}
</script>

<div class="tabs-container">
	<!-- Tab List -->
	<div class="border-b border-gray-200" role="tablist" aria-label="Tab navigation">
		<nav class="flex gap-1 -mb-px" aria-label="Tabs">
			{#each tabs as tab, index}
				<button
					type="button"
					role="tab"
					id="tab-{tab.key}"
					aria-controls="panel-{tab.key}"
					aria-selected={activeKey === tab.key}
					tabindex={activeKey === tab.key ? 0 : -1}
					onclick={() => selectTab(tab.key)}
					onkeydown={(e) => handleKeydown(e, index)}
					class="px-4 py-2.5 text-sm font-medium border-b-2 transition-colors
                       focus:outline-none focus:ring-2 focus:ring-inset focus:ring-gf-maroon
                       {activeKey === tab.key
						? 'border-gf-maroon text-gf-maroon'
						: 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'}"
				>
					{tab.label}
				</button>
			{/each}
		</nav>
	</div>

	<!-- Tab Panels -->
	{#each tabs as tab}
		<div
			role="tabpanel"
			id="panel-{tab.key}"
			aria-labelledby="tab-{tab.key}"
			hidden={activeKey !== tab.key}
			tabindex="0"
			class="py-4 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-gf-maroon rounded-b"
		>
			{#if activeKey === tab.key && content}
				{@render content(tab.key)}
			{/if}
		</div>
	{/each}
</div>
