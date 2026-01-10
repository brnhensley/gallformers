/**
 * Page load function for the ID tool
 *
 * Loads gall data for filtering. URL state is handled client-side via stores.
 */

import { loadGalls } from './stores/results.js';

export async function load({ fetch }) {
	await loadGalls(fetch);

	return {
		title: 'ID Gall'
	};
}
