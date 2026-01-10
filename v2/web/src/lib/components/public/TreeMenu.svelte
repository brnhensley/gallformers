<script>
	/**
	 * TreeMenu - Custom hierarchical tree browser (recursive component)
	 *
	 * A simple tree menu for browsing hierarchical data like taxonomy.
	 * Supports expand/collapse and click-to-navigate.
	 *
	 * @typedef {Object} TreeNode
	 * @property {string} key - Unique identifier for the node
	 * @property {string} label - Display text
	 * @property {string} [url] - Optional URL to navigate to when clicked (leaf nodes)
	 * @property {TreeNode[]} [nodes] - Child nodes (branch nodes)
	 */

	let {
		data = [],
		onitemclick,
		level = 0,
		expandedKeys = $bindable(new Set())
	} = $props();

	function isExpanded(key) {
		return expandedKeys.has(key);
	}

	function toggleExpanded(key) {
		if (expandedKeys.has(key)) {
			expandedKeys.delete(key);
		} else {
			expandedKeys.add(key);
		}
		expandedKeys = new Set(expandedKeys);
	}

	function handleItemClick(item) {
		if (item.nodes && item.nodes.length > 0) {
			// Branch node - toggle expanded
			toggleExpanded(item.key);
		} else if (item.url && onitemclick) {
			// Leaf node with URL - trigger navigation
			onitemclick(item);
		} else if (onitemclick) {
			// Leaf node without URL - still notify
			onitemclick(item);
		}
	}

	function handleKeydown(e, item) {
		if (e.key === 'Enter' || e.key === ' ') {
			e.preventDefault();
			handleItemClick(item);
		} else if (e.key === 'ArrowRight' && item.nodes?.length > 0 && !isExpanded(item.key)) {
			e.preventDefault();
			expandedKeys.add(item.key);
			expandedKeys = new Set(expandedKeys);
		} else if (e.key === 'ArrowLeft' && item.nodes?.length > 0 && isExpanded(item.key)) {
			e.preventDefault();
			expandedKeys.delete(item.key);
			expandedKeys = new Set(expandedKeys);
		}
	}

	// Indentation based on level
	let indent = $derived(`${level * 1.25}rem`);
</script>

<ul class="list-none m-0 p-0" role="tree">
	{#each data as item (item.key)}
		{@const hasChildren = item.nodes && item.nodes.length > 0}
		{@const expanded = isExpanded(item.key)}
		{@const isLeaf = !hasChildren}

		<li role="treeitem" aria-expanded={hasChildren ? expanded : undefined}>
			<div
				class="flex items-center py-1.5 px-2 cursor-pointer hover:bg-gray-100 rounded transition-colors
					{expanded ? 'bg-gray-50' : ''}"
				style="padding-left: {indent}"
				onclick={() => handleItemClick(item)}
				onkeydown={(e) => handleKeydown(e, item)}
				tabindex="0"
				role="button"
			>
				<!-- Expand/collapse icon for branch nodes -->
				{#if hasChildren}
					<span
						class="w-5 h-5 flex items-center justify-center text-gray-500 mr-1 transition-transform {expanded
							? 'rotate-90'
							: ''}"
					>
						<svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
						</svg>
					</span>
				{:else}
					<!-- Spacer for leaf nodes to align text -->
					<span class="w-5 h-5 mr-1"></span>
				{/if}

				<!-- Node label -->
				<span class="flex-1 {isLeaf ? 'text-blue-600 hover:underline' : 'font-medium text-gray-800'}">
					{item.label}
				</span>

				<!-- Child count badge for branch nodes -->
				{#if hasChildren}
					<span class="text-xs text-gray-400 ml-2">
						({item.nodes.length})
					</span>
				{/if}
			</div>

			<!-- Recursive children -->
			{#if hasChildren && expanded}
				<svelte:self
					data={item.nodes}
					{onitemclick}
					level={level + 1}
					bind:expandedKeys
				/>
			{/if}
		</li>
	{/each}
</ul>

{#if data.length === 0 && level === 0}
	<p class="text-sm text-gray-500 p-4">No items to display</p>
{/if}
