/**
 * Load function for genus detail page.
 * Fetches genus data with family and species.
 */
export async function load({ fetch, params }) {
	const { id } = params;

	try {
		// Fetch genus data (includes family and species)
		const genusRes = await fetch(`/api/v2/taxonomy/genera/${id}`);

		if (!genusRes.ok) {
			if (genusRes.status === 404) {
				return {
					genus: null,
					error: 'Genus not found'
				};
			}
			throw new Error(`Failed to fetch genus: ${genusRes.status}`);
		}

		const genus = await genusRes.json();

		return {
			genus,
			family: genus.family || null,
			species: genus.species || []
		};
	} catch (err) {
		console.error('Genus detail fetch error:', err);
		return {
			genus: null,
			error: 'Failed to load genus data'
		};
	}
}
