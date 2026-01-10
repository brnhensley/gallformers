<script>
	import { geoPath, geoAlbers } from 'd3-geo';
	import { feature } from 'topojson-client';
	import topology from '$lib/data/usa-can-topo.json';

	let {
		inRange,
		excludedRange = new Set(),
		editable = false,
		onToggle = () => {}
	} = $props();

	// Albers projection configured for North America (USA + Canada)
	const projection = geoAlbers()
		.center([0, 55]) // Center latitude for NA
		.rotate([96, 0]) // Rotate to center on NA longitude
		.parallels([20, 60]) // Standard parallels for NA
		.scale(800)
		.translate([487, 350]); // Center in viewBox

	const path = geoPath(projection);

	// Extract features from TopoJSON (includes US states + Canadian provinces)
	const features = feature(topology, topology.objects.ne_10m_admin_1_states_provinces).features;

	function getFill(code) {
		if (excludedRange.has(code)) return '#F08080'; // LightCoral - excluded
		if (inRange.has(code)) return '#228B22'; // ForestGreen - in range
		return '#FFFFFF'; // White - neither
	}

	function handleClick(code) {
		if (editable) {
			onToggle(code);
		}
	}

	function handleKeyDown(e, code) {
		if (editable && (e.key === 'Enter' || e.key === ' ')) {
			e.preventDefault();
			onToggle(code);
		}
	}
</script>

<svg viewBox="0 0 975 700" class="w-full h-auto" role="img" aria-label="Range map of North America">
	{#each features as feat}
		{@const postal = feat.properties?.postal ?? ''}
		{@const name = feat.properties?.name ?? 'Unknown'}
		<!-- svelte-ignore a11y_no_static_element_interactions a11y_no_noninteractive_tabindex -->
		<path
			d={path(feat) ?? ''}
			fill={getFill(postal)}
			stroke="#2F4F4F"
			stroke-width="0.5"
			onclick={() => handleClick(postal)}
			onkeydown={(e) => handleKeyDown(e, postal)}
			class={editable ? 'cursor-pointer hover:opacity-80' : ''}
			role={editable ? 'button' : undefined}
			tabindex={editable ? 0 : undefined}
			aria-label={editable ? `Toggle ${name}` : name}
		/>
	{/each}
</svg>
