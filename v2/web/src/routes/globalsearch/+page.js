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
		return {
			query,
			results: data.results || []
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
