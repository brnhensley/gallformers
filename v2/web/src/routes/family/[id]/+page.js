/**
 * Load function for family detail page.
 * Fetches family data with genera.
 */
export async function load({ fetch, params }) {
	const { id } = params;

	try {
		// Fetch family data (includes genera)
		const familyRes = await fetch(`/api/v2/taxonomy/families/${id}`);

		if (!familyRes.ok) {
			if (familyRes.status === 404) {
				return {
					family: null,
					error: 'Family not found'
				};
			}
			throw new Error(`Failed to fetch family: ${familyRes.status}`);
		}

		const family = await familyRes.json();

		// Build tree data for TreeMenu component
		// Shows family -> genera, with genera linking to genus pages
		const treeData = [
			{
				key: family.id.toString(),
				label: family.description ? `${family.name} (${family.description})` : family.name,
				nodes: (family.genera || [])
					.sort((a, b) => a.name.localeCompare(b.name))
					.map((genus) => ({
						key: genus.id.toString(),
						label: genus.description ? `${genus.name} (${genus.description})` : genus.name,
						url: `/genus/${genus.id}`
					}))
			}
		];

		return {
			family,
			treeData,
			initialExpandedKeys: new Set([family.id.toString()])
		};
	} catch (err) {
		console.error('Family detail fetch error:', err);
		return {
			family: null,
			error: 'Failed to load family data'
		};
	}
}
