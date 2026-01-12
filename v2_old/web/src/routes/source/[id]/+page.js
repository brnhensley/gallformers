/**
 * Load function for source detail page.
 * Fetches source data with connected species.
 */
export async function load({ fetch, params }) {
	const { id } = params;

	try {
		const sourceRes = await fetch(`/api/v2/sources/${id}`);

		if (!sourceRes.ok) {
			if (sourceRes.status === 404) {
				return {
					source: null,
					error: 'Source not found'
				};
			}
			throw new Error(`Failed to fetch source: ${sourceRes.status}`);
		}

		const source = await sourceRes.json();

		return {
			source,
			species: source.species || []
		};
	} catch (err) {
		console.error('Source detail fetch error:', err);
		return {
			source: null,
			error: 'Failed to load source data'
		};
	}
}
