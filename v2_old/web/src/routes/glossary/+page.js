// Disable prerendering since the API isn't available during static build
export const prerender = false;

/**
 * Load function for glossary page.
 * Fetches glossary entries server-side.
 */
export async function load({ fetch }) {
	try {
		const response = await fetch('/api/v2/glossary');
		if (!response.ok) {
			console.error('Glossary API error:', response.status);
			return {
				entries: [],
				error: 'Failed to fetch glossary entries'
			};
		}
		const data = await response.json();
		return {
			entries: data.data || []
		};
	} catch (err) {
		console.error('Glossary fetch error:', err);
		return {
			entries: [],
			error: 'Failed to fetch glossary entries'
		};
	}
}
