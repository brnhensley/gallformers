/**
 * URL state sync for the ID tool
 *
 * Provides bidirectional sync between filter state and URL query parameters,
 * keeping filter state shareable via URL.
 */

import { browser } from '$app/environment';
import { goto } from '$app/navigation';
import { filters, EMPTY_QUERY } from './filters.js';
import { DETACHABLE_NONE, DETACHABLE_INTEGRAL, DETACHABLE_DETACHABLE, DETACHABLE_BOTH } from '../utils/gallsearch.js';

// URL parameter names for each filter
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

// Reverse lookup for parsing
const PARAM_TO_FIELD = Object.fromEntries(Object.entries(PARAM_KEYS).map(([k, v]) => [v, k]));

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
 * Serialize filter state to URL search params
 * @param {Object} state - Filter state
 * @returns {URLSearchParams}
 */
export function serializeToParams(state) {
	const params = new URLSearchParams();

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
 * Initialize filter state from current URL
 * Call this when the ID page mounts.
 */
export function initFromUrl() {
	if (!browser) return;

	const params = new URLSearchParams(window.location.search);
	const query = parseUrlParams(params);
	filters.setAll(query);
}

/**
 * Update URL to reflect current filter state
 * @param {Object} state - Filter state
 * @param {Object} [options]
 * @param {boolean} [options.replace=true] - Replace history instead of push
 */
export function syncToUrl(state, options = { replace: true }) {
	if (!browser) return;

	const params = serializeToParams(state);
	const search = params.toString();
	const url = search ? `?${search}` : window.location.pathname;

	goto(url, { replaceState: options.replace, keepFocus: true, noScroll: true });
}

/**
 * Subscribe to filter changes and sync to URL
 * Returns unsubscribe function.
 * @returns {() => void}
 */
export function startUrlSync() {
	if (!browser) return () => {};

	// Initialize from URL on start
	initFromUrl();

	// Sync filter changes to URL (debounced slightly)
	let timeoutId = null;

	const unsubscribe = filters.subscribe((state) => {
		if (timeoutId) clearTimeout(timeoutId);
		timeoutId = setTimeout(() => {
			syncToUrl(state);
		}, 100);
	});

	return () => {
		if (timeoutId) clearTimeout(timeoutId);
		unsubscribe();
	};
}

/**
 * Get a shareable URL with current filters
 * @returns {string}
 */
export function getShareableUrl() {
	if (!browser) return '';

	const state = filters.getState();
	const params = serializeToParams(state);
	const search = params.toString();
	const base = `${window.location.origin}${window.location.pathname}`;

	return search ? `${base}?${search}` : base;
}
