/**
 * Gall search filter logic - ported from libs/utils/gallsearch.ts
 *
 * Filters gall data based on search query criteria.
 */

// Detachable constants
export const DETACHABLE_NONE = '';
export const DETACHABLE_INTEGRAL = 'integral';
export const DETACHABLE_DETACHABLE = 'detachable';
export const DETACHABLE_BOTH = 'both';

// Special filter values
export const LEAF_ANYWHERE = 'leaf (anywhere)';
export const GALL_FORM = 'gall';
export const NONGALL_FORM = 'non-gall';

/**
 * Check if a query value should be ignored (empty/undefined)
 * @param {string | string[] | undefined} o
 * @returns {boolean}
 */
function dontCare(o) {
	const truthy = !!o;
	return !truthy || (truthy && Array.isArray(o) ? o.length === 0 : false);
}

/**
 * Check if all query values are found in the target array
 * @param {string[]} targets - Array of values on the gall
 * @param {string[] | undefined} queryVals - Query values to match
 * @returns {boolean}
 */
function checkArray(targets, queryVals) {
	if (queryVals === undefined) return false;
	return queryVals.every((q) => targets.find((t) => t === q));
}

/**
 * Check if detachable value matches query
 * @param {{ value: string }} gall - Gall's detachable value
 * @param {{ value: string }} query - Query's detachable value
 * @returns {boolean}
 */
function checkDetachable(gall, query) {
	// query of None matches all
	if (query.value === DETACHABLE_NONE) return true;

	// query of Both matches only those with literal Both
	if (query.value === DETACHABLE_BOTH && gall.value === DETACHABLE_BOTH) return true;

	// otherwise must match including matches on Both
	return query.value === gall.value || gall.value === DETACHABLE_BOTH;
}

/**
 * Check if a gall matches the search query
 * @param {Object} gall - The gall to check
 * @param {number} gall.id
 * @param {string} gall.name
 * @param {string[]} [gall.alignments]
 * @param {string[]} [gall.cells]
 * @param {string[]} [gall.colors]
 * @param {{ value: string }} gall.detachable
 * @param {string[]} [gall.forms]
 * @param {string[]} gall.locations
 * @param {string[]} [gall.places]
 * @param {string[]} [gall.seasons]
 * @param {string[]} [gall.shapes]
 * @param {string[]} [gall.textures]
 * @param {boolean} gall.undescribed
 * @param {string[]} [gall.walls]
 * @param {string} [gall.family]
 * @param {Object} query - The search query
 * @param {string[]} query.alignment
 * @param {string[]} query.cells
 * @param {string[]} query.color
 * @param {{ value: string }[]} query.detachable
 * @param {string[]} query.form
 * @param {string[]} query.locations
 * @param {string[]} query.place
 * @param {string[]} query.season
 * @param {string[]} query.shape
 * @param {string[]} query.textures
 * @param {boolean} query.undescribed
 * @param {string[]} query.walls
 * @param {string[]} query.family
 * @returns {boolean}
 */
export function checkGall(gall, query) {
	const alignment = dontCare(query.alignment) || (!!gall.alignments && checkArray(gall.alignments, query.alignment));
	const cells = dontCare(query.cells) || (!!gall.cells && checkArray(gall.cells, query.cells));
	const color = dontCare(query.color) || (!!gall.colors && checkArray(gall.colors, query.color));
	const season = dontCare(query.season) || (!!gall.seasons && checkArray(gall.seasons, query.season));
	const detachable = checkDetachable(gall.detachable, query.detachable[0]);
	const shape = dontCare(query.shape) || (!!gall.shapes && checkArray(gall.shapes, query.shape));
	const walls = dontCare(query.walls) || (!!gall.walls && checkArray(gall.walls, query.walls));

	// Handle "leaf (anywhere)" special location filter
	let location = false;
	if (query.locations.find((l) => l === LEAF_ANYWHERE)) {
		location = gall.locations.some((l) => l.includes('leaf'));
		const locs = query.locations.filter((l) => l !== LEAF_ANYWHERE);
		location = location && (dontCare(locs) || (!!gall.locations && checkArray(gall.locations, locs)));
	} else {
		location = dontCare(query.locations) || (!!gall.locations && checkArray(gall.locations, query.locations));
	}

	const texture = dontCare(query.textures) || (!!gall.textures && checkArray(gall.textures, query.textures));

	// Handle "gall" form filter - means "not non-gall"
	let form = false;
	if (query.form.find((f) => f === GALL_FORM)) {
		const forms = query.form.filter((f) => f !== GALL_FORM);
		// gall selected as a form, which means not non-gall form
		form = !gall.forms.find((f) => f === NONGALL_FORM);
		form = form && (dontCare(forms) || (!!gall.forms && checkArray(gall.forms, forms)));
	} else {
		// gall not selected as a form so we can just do the usual check
		form = dontCare(query.form) || (!!gall.forms && checkArray(gall.forms, query.form));
	}

	const undescribed = !query.undescribed || gall.undescribed;
	const place = dontCare(query.place) || (!!gall.places && checkArray(gall.places, query.place));
	const family = dontCare(query.family) || (!!gall.family && checkArray([gall.family], query.family));

	return (
		alignment &&
		cells &&
		color &&
		season &&
		detachable &&
		shape &&
		walls &&
		location &&
		texture &&
		form &&
		undescribed &&
		place &&
		family
	);
}

/**
 * Filter an array of galls by a search query
 * @param {Object[]} galls - Array of galls to filter
 * @param {Object} query - Search query
 * @returns {Object[]} - Filtered galls
 */
export function filterGalls(galls, query) {
	return galls.filter((gall) => checkGall(gall, query));
}

/** Make helper functions available for unit testing */
export const testables = {
	dontCare,
	checkArray,
	checkDetachable
};
