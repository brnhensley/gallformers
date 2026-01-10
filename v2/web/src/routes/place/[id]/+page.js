/**
 * Load function for place detail page.
 * Fetches place data with parent and hosts.
 */
export async function load({ fetch, params }) {
	const { id } = params;

	try {
		const placeRes = await fetch(`/api/v2/places/${id}`);

		if (!placeRes.ok) {
			if (placeRes.status === 404) {
				return {
					place: null,
					error: 'Place not found'
				};
			}
			throw new Error(`Failed to fetch place: ${placeRes.status}`);
		}

		const place = await placeRes.json();

		return {
			place,
			parent: place.parent || null,
			hosts: place.hosts || []
		};
	} catch (err) {
		console.error('Place detail fetch error:', err);
		return {
			place: null,
			error: 'Failed to load place data'
		};
	}
}
