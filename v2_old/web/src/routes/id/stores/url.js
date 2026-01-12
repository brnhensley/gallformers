/**
 * URL state sync for the ID tool
 *
 * Provides bidirectional sync between filter state and URL query parameters,
 * keeping filter state shareable via URL. Includes host/genus selection
 * for fully shareable links.
 */

import { browser } from '$app/environment';
import { goto } from '$app/navigation';
import { get } from 'svelte/store';
import { filters, EMPTY_QUERY } from './filters.js';
import { selectedHost, selectedGenus } from './results.js';
import { DETACHABLE_NONE, DETACHABLE_INTEGRAL, DETACHABLE_DETACHABLE, DETACHABLE_BOTH } from '../utils/gallsearch.js';

// URL parameter names for each filter (V2 uses short codes)
const PARAM_KEYS = {
	alignment: 'al',
	cells: 'ce',
	color: 'co',
	detachable: 'de',
	form: 'fo',
	locations: 'lo',
	place: 'pl',
	season: 'se',
	shape: 'sh',
	textures: 'te',
	undescribed: 'un',
	walls: 'wa',
	family: 'fa'
};

// V1 parameter names (for backwards compatibility)
const V1_PARAM_KEYS = {
	alignment: 'alignment',
	cells: 'cells',
	color: 'color',
	detachable: 'detachable',
	form: 'form',
	locations: 'locations',
	place: 'place',
	season: 'season',
	shape: 'shape',
	textures: 'textures',
	undescribed: 'undescribed',
	walls: 'walls',
	family: 'family'
};

// URL parameter names for host/genus selection (V2)
const SELECTION_PARAM_KEYS = {
	host: 'h',           // Host name
	genus: 'g',          // Genus/section name
	genusType: 'gt'      // Genus type ('genus' or 'section')
};

// V1 selection parameter names (for backwards compatibility)
const V1_SELECTION_PARAM_KEYS = {
	hostOrTaxon: 'hostOrTaxon',  // V1 uses combined host or taxon name
	type: 'type'                  // V1 uses 'type' for 'host', 'genus', or 'section'
};

// Reverse lookup for parsing - includes both V2 short codes and V1 full names
const PARAM_TO_FIELD = {
	// V2 short codes
	...Object.fromEntries(Object.entries(PARAM_KEYS).map(([k, v]) => [v, k])),
	// V1 full names (these map field name to itself)
	...Object.fromEntries(Object.keys(V1_PARAM_KEYS).map((k) => [k, k]))
};

/**
 * Parse detachable value from URL param
 * @param {string | null} value
 * @returns {{ id: number, value: string }}
 */
function parseDetachable(value) {
	switch (value) {
		case 'integral':
			return { id: 1, value: DETACHABLE_INTEGRAL };
		case 'detachable':
			return { id: 2, value: DETACHABLE_DETACHABLE };
		case 'both':
			return { id: 3, value: DETACHABLE_BOTH };
		default:
			return { id: 0, value: DETACHABLE_NONE };
	}
}

/**
 * Serialize detachable for URL
 * @param {{ value: string }} detachable
 * @returns {string | null}
 */
function serializeDetachable(detachable) {
	if (detachable.value === DETACHABLE_NONE) return null;
	return detachable.value;
}

/**
 * Parse URL search params into filter state
 * @param {URLSearchParams} params
 * @returns {Object}
 */
export function parseUrlParams(params) {
	const query = { ...EMPTY_QUERY };

	for (const [param, value] of params) {
		const field = PARAM_TO_FIELD[param];
		if (!field) continue;

		if (field === 'detachable') {
			query.detachable = [parseDetachable(value)];
		} else if (field === 'undescribed') {
			query.undescribed = value === '1' || value === 'true';
		} else {
			// Array fields - split by comma
			const values = value.split(',').filter(Boolean);
			query[field] = values;
		}
	}

	return query;
}

/**
 * Parse URL search params for host/genus selection
 * Supports both V2 params (h, g, gt) and V1 params (hostOrTaxon, type)
 * Returns raw names/types that need to be looked up via API
 * @param {URLSearchParams} params
 * @returns {{ hostName: string | null, genusName: string | null, genusType: string | null }}
 */
export function parseSelectionParams(params) {
	// Try V2 params first
	let hostName = params.get(SELECTION_PARAM_KEYS.host);
	let genusName = params.get(SELECTION_PARAM_KEYS.genus);
	let genusType = params.get(SELECTION_PARAM_KEYS.genusType);

	// Fall back to V1 params if V2 params not present
	if (!hostName && !genusName) {
		const v1Name = params.get(V1_SELECTION_PARAM_KEYS.hostOrTaxon);
		const v1Type = params.get(V1_SELECTION_PARAM_KEYS.type);

		if (v1Name && v1Type) {
			if (v1Type === 'host') {
				hostName = v1Name;
			} else if (v1Type === 'genus' || v1Type === 'section') {
				genusName = v1Name;
				genusType = v1Type;
			}
		}
	}

	return {
		hostName,
		genusName,
		genusType: genusType || 'genus'
	};
}

/**
 * Serialize filter state to URL search params
 * @param {Object} state - Filter state
 * @param {Object} [selection] - Optional host/genus selection
 * @param {Object} [selection.host] - Selected host
 * @param {Object} [selection.genus] - Selected genus
 * @returns {URLSearchParams}
 */
export function serializeToParams(state, selection = {}) {
	const params = new URLSearchParams();

	// Add host/genus selection first (most important for shareable URLs)
	if (selection.host) {
		params.set(SELECTION_PARAM_KEYS.host, selection.host.name);
	}
	if (selection.genus) {
		params.set(SELECTION_PARAM_KEYS.genus, selection.genus.name);
		if (selection.genus.type) {
			params.set(SELECTION_PARAM_KEYS.genusType, selection.genus.type);
		}
	}

	// Add filter state
	for (const [field, paramKey] of Object.entries(PARAM_KEYS)) {
		const value = state[field];

		if (field === 'detachable') {
			const serialized = serializeDetachable(value[0]);
			if (serialized) {
				params.set(paramKey, serialized);
			}
		} else if (field === 'undescribed') {
			if (value) {
				params.set(paramKey, '1');
			}
		} else if (Array.isArray(value) && value.length > 0) {
			params.set(paramKey, value.join(','));
		}
	}

	return params;
}

/**
 * Format host label for display (matches HostPicker format)
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
 * Format taxon label for display (matches GenusPicker format)
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
 * Look up a host by name via API
 * @param {string} name - Host name to search for
 * @param {string} [apiBase='/api/v2'] - API base URL
 * @returns {Promise<Object | null>}
 */
async function lookupHostByName(name, apiBase = '/api/v2') {
	try {
		const response = await fetch(`${apiBase}/hosts?q=${encodeURIComponent(name)}&limit=10`);
		if (!response.ok) return null;
		const result = await response.json();
		// Find exact match
		const host = result.data?.find((h) => h.name === name);
		if (host) {
			// Add displayName for Typeahead component
			host.displayName = formatHostLabel(host);
		}
		return host || null;
	} catch (err) {
		console.error('Error looking up host:', err);
		return null;
	}
}

/**
 * Look up a genus/section by name via API
 * @param {string} name - Genus/section name to search for
 * @param {string} type - Type ('genus' or 'section')
 * @param {string} [apiBase='/api/v2'] - API base URL
 * @returns {Promise<Object | null>}
 */
async function lookupGenusByName(name, type, apiBase = '/api/v2') {
	try {
		const response = await fetch(
			`${apiBase}/taxonomy/search?q=${encodeURIComponent(name)}&types=${type}`
		);
		if (!response.ok) return null;
		const data = await response.json();
		// Find exact match
		const genus = data?.find((t) => t.name === name && t.type === type);
		if (genus) {
			// Add displayName for Typeahead component
			genus.displayName = formatTaxonLabel(genus);
		}
		return genus || null;
	} catch (err) {
		console.error('Error looking up genus:', err);
		return null;
	}
}

/**
 * Initialize filter state from current URL
 * Call this when the ID page mounts.
 * @param {string} [apiBase='/api/v2'] - API base URL for lookups
 */
export async function initFromUrl(apiBase = '/api/v2') {
	if (!browser) return;

	const params = new URLSearchParams(window.location.search);
	const paramsObj = Object.fromEntries(params);

	return initFromUrlParams(paramsObj, apiBase);
}

/**
 * Initialize filter state from URL params object
 * Can be called with params from load function or from URL directly
 * @param {Object} paramsObj - Object with URL search params
 * @param {string} [apiBase='/api/v2'] - API base URL for lookups
 */
export async function initFromUrlParams(paramsObj, apiBase = '/api/v2') {
	if (!browser) return;

	// Convert params object to URLSearchParams for parsing functions
	const params = new URLSearchParams(paramsObj);

	// Parse and restore filter state
	const query = parseUrlParams(params);
	filters.setAll(query);

	// Parse and restore host/genus selection
	const selection = parseSelectionParams(params);

	// Look up host by name if specified in URL
	if (selection.hostName) {
		const host = await lookupHostByName(selection.hostName, apiBase);
		if (host) {
			selectedHost.set(host);
		}
	}

	// Look up genus by name if specified in URL
	if (selection.genusName) {
		const genus = await lookupGenusByName(selection.genusName, selection.genusType, apiBase);
		if (genus) {
			selectedGenus.set(genus);
		}
	}
}

/**
 * Update URL to reflect current filter state and selection
 * @param {Object} state - Filter state
 * @param {Object} [selection] - Host/genus selection
 * @param {Object} [options]
 * @param {boolean} [options.replace=true] - Replace history instead of push
 */
export function syncToUrl(state, selection = {}, options = { replace: true }) {
	if (!browser) return;

	const params = serializeToParams(state, selection);
	const search = params.toString();
	const url = search ? `?${search}` : window.location.pathname;

	goto(url, { replaceState: options.replace, keepFocus: true, noScroll: true });
}

/**
 * Subscribe to filter and selection changes and sync to URL
 * Returns unsubscribe function.
 * @returns {() => void}
 */
export function startUrlSync() {
	if (!browser) return () => {};

	// Track current selection state
	let currentHost = null;
	let currentGenus = null;

	// Flag to prevent URL sync during initialization
	let initializing = true;

	// Sync changes to URL (debounced slightly)
	let timeoutId = null;

	function scheduleSync() {
		// Don't sync to URL while still initializing from URL
		if (initializing) return;

		if (timeoutId) clearTimeout(timeoutId);
		timeoutId = setTimeout(() => {
			const filterState = get(filters);
			syncToUrl(filterState, { host: currentHost, genus: currentGenus });
		}, 100);
	}

	// Subscribe to filter changes
	const unsubFilters = filters.subscribe(() => {
		scheduleSync();
	});

	// Subscribe to host selection changes
	const unsubHost = selectedHost.subscribe((host) => {
		currentHost = host;
		scheduleSync();
	});

	// Subscribe to genus selection changes
	const unsubGenus = selectedGenus.subscribe((genus) => {
		currentGenus = genus;
		scheduleSync();
	});

	// Enable syncing after a short delay to let initial state settle
	// (The page component handles initializing from URL params via load function)
	setTimeout(() => {
		initializing = false;
	}, 200);

	return () => {
		if (timeoutId) clearTimeout(timeoutId);
		unsubFilters();
		unsubHost();
		unsubGenus();
	};
}

/**
 * Get a shareable URL with current filters and selection
 * @returns {string}
 */
export function getShareableUrl() {
	if (!browser) return '';

	const state = filters.getState();
	const host = get(selectedHost);
	const genus = get(selectedGenus);
	const params = serializeToParams(state, { host, genus });
	const search = params.toString();
	const base = `${window.location.origin}${window.location.pathname}`;

	return search ? `${base}?${search}` : base;
}
