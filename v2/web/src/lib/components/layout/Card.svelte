<script lang="ts">
	import type { Snippet } from 'svelte';

	let {
		title = undefined,
		children
	}: {
		title?: string;
		children: Snippet;
	} = $props();
</script>

<div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
	{#if title}
		<h3 class="text-lg font-medium text-gray-900 mb-4">{title}</h3>
	{/if}
	{@render children?.()}
</div>
