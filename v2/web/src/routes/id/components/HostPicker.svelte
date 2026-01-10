<script>
	/**
	 * HostPicker - Typeahead for selecting a host species
	 *
	 * Searches for host species and allows selection for filtering galls.
	 */

	import Typeahead from '$lib/components/forms/Typeahead.svelte';
	import { selectedHost } from '../stores/results.js';

	let { apiBase = '/api/v2', disabled = false } = $props();

	// Local state bound to typeahead
	let selected = $state(null);

	// Sync store to local state
	$effect(() => {
		const unsub = selectedHost.subscribe((value) => {
			selected = value;
		});
		return unsub;
	});

	// Sync local state changes to store
	$effect(() => {
		selectedHost.set(selected);
	});

	/**
	 * Search for hosts matching the query
	 * @param {string} filterText - Search text
	 * @returns {Promise<Array>}
	 */
	async function searchHosts(filterText) {
		if (!filterText || filterText.length < 2) {
			return [];
		}

		try {
			const response = await fetch(`${apiBase}/hosts?q=${encodeURIComponent(filterText)}`);
			if (!response.ok) {
				console.error('Failed to search hosts:', response.status);
				return [];
			}
			const result = await response.json();
			// Format for display: name (aliases)
			return result.data.map((host) => ({
				...host,
				displayName: formatHostLabel(host)
			}));
		} catch (err) {
			console.error('Error searching hosts:', err);
			return [];
		}
	}

	/**
	 * Format host label for display
	 * @param {Object} host
	 * @returns {string}
	 */
	function formatHostLabel(host) {
		if (!host) return '';
		const aliases =
			host.aliases && host.aliases.length > 0
				? host.aliases
						.map((a) => a.name || a)
						.sort()
						.join(', ')
				: '';
		return aliases ? `${host.name} (${aliases})` : host.name;
	}

	/**
	 * Clear the selection
	 */
	function clearSelection() {
		selected = null;
	}
</script>

<div class="host-picker" class:opacity-50={disabled}>
	{#key selected?.id}
		<Typeahead bind:selected label="Host" searchFn={searchHosts} labelKey="displayName" />
	{/key}
	{#if selected}
		<button
			type="button"
			class="mt-1 text-sm text-gray-500 hover:text-gray-700 underline"
			onclick={clearSelection}
		>
			Clear selection
		</button>
	{/if}
</div>
