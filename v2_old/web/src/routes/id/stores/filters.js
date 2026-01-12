/**
 * Filter state store for the ID tool
 *
 * Manages all filter selections for gall identification.
 */

import { writable, get } from 'svelte/store';
import { DETACHABLE_NONE } from '../utils/gallsearch.js';

/**
 * Empty search query - default state for filters
 */
export const EMPTY_QUERY = {
	detachable: [{ id: 0, value: DETACHABLE_NONE }],
	alignment: [],
	walls: [],
	locations: [],
	textures: [],
	color: [],
	season: [],
	shape: [],
	cells: [],
	form: [],
	undescribed: false,
	place: [],
	family: []
};

/**
 * Create the filter store with actions
 */
function createFiltersStore() {
	const { subscribe, set, update } = writable({ ...EMPTY_QUERY });

	return {
		subscribe,

		/**
		 * Set a specific filter field
		 * @param {string} field - The filter field name
		 * @param {any} value - The new value
		 */
		setFilter(field, value) {
			update((state) => ({ ...state, [field]: value }));
		},

		/**
		 * Add a value to an array filter field
		 * @param {string} field - The filter field name
		 * @param {string} value - Value to add
		 */
		addToFilter(field, value) {
			update((state) => {
				const current = state[field];
				if (Array.isArray(current) && !current.includes(value)) {
					return { ...state, [field]: [...current, value] };
				}
				return state;
			});
		},

		/**
		 * Remove a value from an array filter field
		 * @param {string} field - The filter field name
		 * @param {string} value - Value to remove
		 */
		removeFromFilter(field, value) {
			update((state) => {
				const current = state[field];
				if (Array.isArray(current)) {
					return { ...state, [field]: current.filter((v) => v !== value) };
				}
				return state;
			});
		},

		/**
		 * Toggle a value in an array filter field
		 * @param {string} field - The filter field name
		 * @param {string} value - Value to toggle
		 */
		toggleFilter(field, value) {
			update((state) => {
				const current = state[field];
				if (Array.isArray(current)) {
					if (current.includes(value)) {
						return { ...state, [field]: current.filter((v) => v !== value) };
					}
					return { ...state, [field]: [...current, value] };
				}
				return state;
			});
		},

		/**
		 * Set the detachable filter
		 * @param {{ id: number, value: string }} detachable
		 */
		setDetachable(detachable) {
			update((state) => ({ ...state, detachable: [detachable] }));
		},

		/**
		 * Toggle undescribed filter
		 */
		toggleUndescribed() {
			update((state) => ({ ...state, undescribed: !state.undescribed }));
		},

		/**
		 * Reset all filters to empty state
		 */
		reset() {
			set({ ...EMPTY_QUERY });
		},

		/**
		 * Set entire filter state (for URL restoration)
		 * @param {Object} query - Complete query object
		 */
		setAll(query) {
			set({ ...EMPTY_QUERY, ...query });
		},

		/**
		 * Get current filter state
		 * @returns {Object}
		 */
		getState() {
			return get({ subscribe });
		},

		/**
		 * Check if any filters are active
		 * @returns {boolean}
		 */
		hasActiveFilters() {
			const state = get({ subscribe });
			return (
				state.alignment.length > 0 ||
				state.walls.length > 0 ||
				state.locations.length > 0 ||
				state.textures.length > 0 ||
				state.color.length > 0 ||
				state.season.length > 0 ||
				state.shape.length > 0 ||
				state.cells.length > 0 ||
				state.form.length > 0 ||
				state.place.length > 0 ||
				state.family.length > 0 ||
				state.undescribed ||
				state.detachable[0]?.value !== DETACHABLE_NONE
			);
		}
	};
}

export const filters = createFiltersStore();
