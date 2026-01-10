/**
 * Load function for gall detail page.
 * Fetches gall data, taxonomy, sources, and images.
 */
export async function load({ fetch, params }) {
	const { id } = params;

	try {
		// Fetch gall data, taxonomy, sources, and images in parallel
		const [gallRes, taxonomyRes, sourcesRes, imagesRes] = await Promise.all([
			fetch(`/api/v2/galls/${id}`),
			fetch(`/api/v2/taxonomy?id=${id}`),
			fetch(`/api/v2/sources?speciesid=${id}`),
			fetch(`/api/v2/species/${id}/images`).catch(() => null) // Images endpoint may not exist
		]);

		if (!gallRes.ok) {
			if (gallRes.status === 404) {
				return {
					gall: null,
					error: 'Gall not found'
				};
			}
			throw new Error(`Failed to fetch gall: ${gallRes.status}`);
		}

		const gall = await gallRes.json();
		const taxonomy = taxonomyRes.ok ? await taxonomyRes.json() : null;
		const sources = sourcesRes.ok ? await sourcesRes.json() : [];
		const images = imagesRes?.ok ? await imagesRes.json() : [];

		// Build range from hosts' places if available
		// Note: Current API doesn't include places in gall detail, so this may be empty
		const range = new Set();
		const excludedRange = new Set();

		// Transform sources to match SourceList component expectations
		// API returns SourceWithSpeciesSourceResponse: { id, title, author, ..., speciessource: { id, description, useasdefault, externallink } }
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

		// Find default source (by source ID, not speciessource ID)
		const defaultSource = sources.find((s) => s.speciessource?.useasdefault === 1);
		const defaultSourceId = defaultSource?.id || (sources.length > 0 ? sources[0].id : null);

		// Transform images for ImageGallery component
		const transformedImages = images.map((img) => ({
			id: img.id,
			url: `https://dhz6u1p7t6okk.cloudfront.net/${img.path}`,
			alt: gall.name,
			caption: img.caption || '',
			creator: img.creator || '',
			license: img.license || '',
			licenseLink: img.licenselink || '',
			sourceLink: img.sourcelink || ''
		}));

		return {
			gall,
			taxonomy,
			sources: transformedSources,
			images: transformedImages,
			defaultSourceId,
			range,
			excludedRange
		};
	} catch (err) {
		console.error('Gall detail fetch error:', err);
		return {
			gall: null,
			error: 'Failed to load gall data'
		};
	}
}
