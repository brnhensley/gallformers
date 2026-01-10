/**
 * Load function for global search page.
 * Fetches search results from the API and syncs with URL query param.
 */
export async function load({ url, fetch }) {
	const query = url.searchParams.get('q') || '';

	// Return empty results if no query
	if (!query.trim()) {
		return {
			query: '',
			results: []
		};
	}

	try {
		const response = await fetch(`/api/v2/search?q=${encodeURIComponent(query)}`);

		if (!response.ok) {
			console.error('Search API error:', response.status);
			return {
				query,
				results: [],
				error: 'Failed to fetch search results'
			};
		}

		const data = await response.json();

		// Transform grouped API response into flat results array
		const results = [];
		let uidCounter = 0;

		// Add species (galls and plants based on taxoncode)
		if (data.species) {
			for (const sp of data.species) {
				const type = sp.taxoncode === 'plant' ? 'plant' : 'gall';
				results.push({
					uid: `species-${uidCounter++}`,
					type,
					id: sp.id,
					name: sp.name,
					aliases: sp.aliases || []
				});
			}
		}

		// Add glossary entries
		if (data.glossary) {
			for (const entry of data.glossary) {
				results.push({
					uid: `glossary-${uidCounter++}`,
					type: 'entry',
					id: entry.id,
					name: entry.word,
					aliases: []
				});
			}
		}

		// Add sources
		if (data.sources) {
			for (const source of data.sources) {
				results.push({
					uid: `source-${uidCounter++}`,
					type: 'source',
					id: source.id,
					name: source.source,
					aliases: []
				});
			}
		}

		// Add taxonomy entries (genus, section, family)
		if (data.taxa) {
			for (const taxon of data.taxa) {
				results.push({
					uid: `taxon-${uidCounter++}`,
					type: taxon.type, // genus, section, family
					id: taxon.id,
					name: taxon.name,
					aliases: []
				});
			}
		}

		// Add places
		if (data.places) {
			for (const place of data.places) {
				results.push({
					uid: `place-${uidCounter++}`,
					type: 'place',
					id: place.id,
					name: place.name,
					aliases: []
				});
			}
		}

		return {
			query,
			results
		};
	} catch (err) {
		console.error('Search fetch error:', err);
		return {
			query,
			results: [],
			error: 'Failed to fetch search results'
		};
	}
}
