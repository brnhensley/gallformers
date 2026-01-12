/**
 * Results derived store for the ID tool
 *
 * Provides filtered gall results based on current filter state and gall data.
 */

import { writable, derived } from 'svelte/store';
import { filters } from './filters.js';
import { filterGalls } from '../utils/gallsearch.js';

/**
 * Store for the complete gall dataset
 * Set this when gall data is loaded from the API.
 */
export const galls = writable([]);

/**
 * Loading state for gall data
 */
export const loading = writable(false);

/**
 * Error state for gall data loading
 */
export const error = writable(null);

/**
 * Store for selected host filter (separate from main filters as it requires API lookup)
 */
export const selectedHost = writable(null);

/**
 * Store for selected genus filter (separate from main filters as it requires API lookup)
 */
export const selectedGenus = writable(null);

/**
 * Derived store that filters galls by selected host.
 * This is applied FIRST to narrow to host-specific galls.
 */
export const gallsForHost = derived([galls, selectedHost], ([$galls, $host]) => {
	if (!$host) {
		return $galls;
	}
	return $galls.filter((gall) => {
		if (!gall.hosts) return false;
		return gall.hosts.some((h) => h.id === $host.id || h.name === $host.name);
	});
});

/**
 * Derived store that filters by genus after host filtering.
 * This gives us the total pool of galls for the selected host/genus combination.
 */
export const gallsForSelection = derived([gallsForHost, selectedGenus], ([$galls, $genus]) => {
	if (!$genus) {
		return $galls;
	}
	return $galls.filter((gall) => {
		if (!gall.genus) return false;
		return gall.genus === $genus.name || gall.genus === $genus;
	});
});

/**
 * Derived store for total gall count - reflects the count for selected host/genus.
 * This is the "total" shown in "Showing X of Y galls".
 */
export const totalCount = derived(gallsForSelection, ($galls) => $galls.length);

/**
 * Derived store that applies filter panel filters to the host/genus selection.
 * This is the final filtered result.
 */
export const finalResults = derived([gallsForSelection, filters], ([$galls, $filters]) => {
	if ($galls.length === 0) {
		return [];
	}
	return filterGalls($galls, $filters);
});

/**
 * Final result count
 */
export const finalResultCount = derived(finalResults, ($results) => $results.length);

// Legacy aliases for compatibility with existing components
export const results = finalResults;
export const resultCount = finalResultCount;

/**
 * Transform API response to match filter logic expectations.
 * @param {Object} gall - Raw gall from API
 * @returns {Object} - Transformed gall
 */
function transformGall(gall) {
	return {
		...gall,
		// Convert detachable string to object with value property
		detachable: { value: gall.detachable || '' }
	};
}

/**
 * Load galls data from API
 * @param {typeof fetch} fetcher - Fetch function (from SvelteKit load or browser)
 * @param {Object} [options]
 * @param {string} [options.apiBase='/api/v2'] - API base URL
 */
export async function loadGalls(fetcher, options = {}) {
	const apiBase = options.apiBase || '/api/v2';

	loading.set(true);
	error.set(null);

	try {
		const response = await fetcher(`${apiBase}/galls/id`);
		if (!response.ok) {
			throw new Error(`Failed to load galls: ${response.status}`);
		}
		const data = await response.json();
		// Transform each gall to match expected filter logic format
		const transformedData = data.map(transformGall);
		galls.set(transformedData);
	} catch (err) {
		error.set(err.message || 'Failed to load galls');
		galls.set([]);
	} finally {
		loading.set(false);
	}
}

/**
 * Reset all data stores
 */
export function resetResults() {
	galls.set([]);
	selectedHost.set(null);
	selectedGenus.set(null);
	error.set(null);
	filters.reset();
}
