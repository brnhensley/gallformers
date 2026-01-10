<script>
	/**
	 * GenusPicker - Typeahead for selecting a genus or section
	 *
	 * Searches for genera and sections and allows selection for filtering galls.
	 */

	import Typeahead from '$lib/components/forms/Typeahead.svelte';
	import { selectedGenus } from '../stores/results.js';

	let { apiBase = '/api/v2', disabled = false } = $props();

	// Local state bound to typeahead
	let selected = $state(null);

	// Sync store to local state on mount
	$effect(() => {
		const unsub = selectedGenus.subscribe((value) => {
			selected = value;
		});
		return unsub;
	});

	// Sync local state changes to store
	$effect(() => {
		selectedGenus.set(selected);
	});

	/**
	 * Search for genera/sections matching the query
	 * @param {string} filterText - Search text
	 * @returns {Promise<Array>}
	 */
	async function searchGenera(filterText) {
		if (!filterText || filterText.length < 2) {
			return [];
		}

		try {
			// Search both genera and sections
			const response = await fetch(
				`${apiBase}/taxonomy/search?q=${encodeURIComponent(filterText)}&types=genus,section`
			);
			if (!response.ok) {
				console.error('Failed to search genera:', response.status);
				return [];
			}
			const data = await response.json();
			// Format for display: name (description)
			return data.map((taxon) => ({
				...taxon,
				displayName: formatTaxonLabel(taxon)
			}));
		} catch (err) {
			console.error('Error searching genera:', err);
			return [];
		}
	}

	/**
	 * Format taxon label for display
	 * @param {Object} taxon
	 * @returns {string}
	 */
	function formatTaxonLabel(taxon) {
		if (!taxon) return '';
		const desc = taxon.description ? ` - ${taxon.description}` : '';
		const typeLabel = taxon.type === 'section' ? ' [Section]' : '';
		return `${taxon.name}${typeLabel}${desc}`;
	}

	/**
	 * Clear the selection
	 */
	function clearSelection() {
		selected = null;
	}
</script>

<div class="genus-picker" class:opacity-50={disabled}>
	<Typeahead bind:selected label="Genus / Section" searchFn={searchGenera} labelKey="displayName" />
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
