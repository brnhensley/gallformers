/**
 * Load function for gall detail page.
 * Fetches gall data, taxonomy, sources, and images.
 */
export async function load({ fetch, params }) {
	const { id } = params;

	try {
		// Fetch gall data, taxonomy, sources, images, and related galls in parallel
		const [gallRes, taxonomyRes, sourcesRes, imagesRes, relatedRes] = await Promise.all([
			fetch(`/api/v2/galls/${id}`),
			fetch(`/api/v2/taxonomy?id=${id}`),
			fetch(`/api/v2/sources?speciesid=${id}`),
			fetch(`/api/v2/galls/${id}/images`),
			fetch(`/api/v2/galls/${id}/related`)
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
		const relatedGalls = relatedRes?.ok ? await relatedRes.json() : [];

		// Build range from gall's places (derived from hosts) and excluded places
		const range = new Set();
		if (gall.places && gall.places.length > 0) {
			for (const place of gall.places) {
				range.add(place);
			}
		}
		const excludedRange = new Set();
		if (gall.excludedPlaces && gall.excludedPlaces.length > 0) {
			for (const place of gall.excludedPlaces) {
				excludedRange.add(place);
			}
		}

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
		// API response includes: id, path, url, creator, attribution, sourcelink, license, licenselink, caption
		const transformedImages = images.map((img) => ({
			id: img.id,
			url: img.url, // Full URL already provided by API
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
			excludedRange,
			relatedGalls
		};
	} catch (err) {
		console.error('Gall detail fetch error:', err);
		return {
			gall: null,
			error: 'Failed to load gall data'
		};
	}
}
