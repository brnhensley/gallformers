/**
 * Load function for section detail page.
 * Fetches section data with species.
 */
export async function load({ fetch, params }) {
	const { id } = params;

	try {
		const sectionRes = await fetch(`/api/v2/taxonomy/sections/${id}`);

		if (!sectionRes.ok) {
			if (sectionRes.status === 404) {
				return {
					section: null,
					error: 'Section not found'
				};
			}
			throw new Error(`Failed to fetch section: ${sectionRes.status}`);
		}

		const section = await sectionRes.json();

		return {
			section,
			species: section.species || []
		};
	} catch (err) {
		console.error('Section detail fetch error:', err);
		return {
			section: null,
			error: 'Failed to load section data'
		};
	}
}
