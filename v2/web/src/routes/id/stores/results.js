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
 * Derived store that provides filtered results
 * Automatically recomputes when filters or galls change.
 */
export const results = derived([galls, filters], ([$galls, $filters]) => {
	if ($galls.length === 0) {
		return [];
	}
	return filterGalls($galls, $filters);
});

/**
 * Derived store for result count
 */
export const resultCount = derived(results, ($results) => $results.length);

/**
 * Derived store for total gall count
 */
export const totalCount = derived(galls, ($galls) => $galls.length);

/**
 * Store for selected host filter (separate from main filters as it requires API lookup)
 */
export const selectedHost = writable(null);

/**
 * Store for selected genus filter (separate from main filters as it requires API lookup)
 */
export const selectedGenus = writable(null);

/**
 * Derived store that filters results further by host if selected
 */
export const filteredByHost = derived([results, selectedHost], ([$results, $host]) => {
	if (!$host) {
		return $results;
	}
	// Filter results to only show galls that have this host
	// This requires the gall data to include host information
	return $results.filter((gall) => {
		if (!gall.hosts) return false;
		return gall.hosts.some((h) => h.id === $host.id || h.name === $host.name);
	});
});

/**
 * Derived store that filters results further by genus if selected
 */
export const filteredByGenus = derived([filteredByHost, selectedGenus], ([$results, $genus]) => {
	if (!$genus) {
		return $results;
	}
	// Filter results to only show galls in this genus
	return $results.filter((gall) => {
		if (!gall.genus) return false;
		return gall.genus === $genus.name || gall.genus === $genus;
	});
});

/**
 * Final results store - combines all filters
 */
export const finalResults = filteredByGenus;

/**
 * Final result count
 */
export const finalResultCount = derived(finalResults, ($results) => $results.length);

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
		galls.set(data);
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
