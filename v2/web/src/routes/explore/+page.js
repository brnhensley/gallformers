/**
 * Load function for explore page.
 * Fetches hierarchical tree data for galls, undescribed galls, and hosts.
 */
export async function load({ fetch }) {
	try {
		const response = await fetch('/api/v2/explore');

		if (!response.ok) {
			console.error('Explore API error:', response.status);
			return {
				galls: [],
				undescribed: [],
				hosts: [],
				error: 'Failed to load explore data'
			};
		}

		const data = await response.json();

		return {
			galls: data.galls || [],
			undescribed: data.undescribed || [],
			hosts: data.hosts || []
		};
	} catch (err) {
		console.error('Explore fetch error:', err);
		return {
			galls: [],
			undescribed: [],
			hosts: [],
			error: 'Failed to load explore data'
		};
	}
}
