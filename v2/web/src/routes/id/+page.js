/**
 * Page load function for the ID tool
 *
 * Loads gall data for filtering. URL params are passed to the page for client-side processing.
 */

import { loadGalls } from './stores/results.js';

export async function load({ fetch, url }) {
	await loadGalls(fetch);

	// Pass URL search params to the page component
	// This ensures params are available even on client-side navigation
	const searchParams = Object.fromEntries(url.searchParams);

	return {
		title: 'ID Gall',
		searchParams
	};
}
