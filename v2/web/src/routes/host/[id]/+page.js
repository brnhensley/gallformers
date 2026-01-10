/**
 * Load function for host detail page.
 * Fetches host data, taxonomy, sources, and images.
 */
export async function load({ fetch, params }) {
	const { id } = params;

	try {
		// Fetch host data, taxonomy, sources, and images in parallel
		const [hostRes, taxonomyRes, sourcesRes, imagesRes] = await Promise.all([
			fetch(`/api/v2/hosts/${id}`),
			fetch(`/api/v2/taxonomy?id=${id}`),
			fetch(`/api/v2/sources?speciesid=${id}`),
			fetch(`/api/v2/species/${id}/images`).catch(() => null)
		]);

		if (!hostRes.ok) {
			if (hostRes.status === 404) {
				return {
					host: null,
					error: 'Host not found'
				};
			}
			throw new Error(`Failed to fetch host: ${hostRes.status}`);
		}

		const host = await hostRes.json();
		const taxonomy = taxonomyRes.ok ? await taxonomyRes.json() : null;
		const sources = sourcesRes.ok ? await sourcesRes.json() : [];
		const images = imagesRes?.ok ? await imagesRes.json() : [];

		// Build range from places
		const range = new Set();
		if (host.places && host.places.length > 0) {
			for (const place of host.places) {
				if (place.code) {
					range.add(place.code);
				}
			}
		}

		// Transform sources to match SourceList component expectations
		const transformedSources = sources.map((s) => ({
			id: s.speciessource?.id || s.id,
			sourceId: s.id,
			source: {
				id: s.id,
				title: s.title,
				author: s.author,
				pubyear: s.pubyear,
				license: s.license,
				licenseLink: s.licenselink
			},
			description: s.speciessource?.description || '',
			externalLink: s.speciessource?.externallink || ''
		}));

		// Find default source
		const defaultSource = sources.find((s) => s.speciessource?.useasdefault === 1);

		// Transform images for ImageGallery component
		const transformedImages = images.map((img) => ({
			id: img.id,
			url: `https://dhz6u1p7t6okk.cloudfront.net/${img.path}`,
			alt: host.name,
			caption: img.caption || '',
			creator: img.creator || '',
			license: img.license || '',
			licenseLink: img.licenselink || '',
			sourceLink: img.sourcelink || ''
		}));

		return {
			host,
			taxonomy,
			sources: transformedSources,
			images: transformedImages,
			defaultSourceId: defaultSource?.id || null,
			range
		};
	} catch (err) {
		console.error('Host detail fetch error:', err);
		return {
			host: null,
			error: 'Failed to load host data'
		};
	}
}
