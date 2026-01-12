<script>
	import { onMount } from 'svelte';
	import { geoPath, geoConicEqualArea } from 'd3-geo';
	import { zoom } from 'd3-zoom';
	import { select } from 'd3-selection';
	import { feature } from 'topojson-client';

	let {
		inRange,
		excludedRange = new Set(),
		editable = false,
		onToggle = () => {}
	} = $props();

	let features = $state([]);
	let loading = $state(true);
	let tooltip = $state({ show: false, x: 0, y: 0, text: '' });
	let transform = $state({ k: 1, x: 0, y: 0 });
	let modalSvgElement = $state(null);
	let modalOpen = $state(false);
	let zoomBehavior = $state(null);

	// Projection matching V1: geoConicEqualArea with same config
	const projection = geoConicEqualArea()
		.center([-4, 48])
		.parallels([29.5, 45.5])
		.rotate([96, 0, 0])
		.scale(750)
		.translate([400, 300]);

	const path = geoPath(projection);

	onMount(async () => {
		const res = await fetch('/data/usa-can-topo.json');
		const topology = await res.json();
		features = feature(topology, topology.objects.ne_10m_admin_1_states_provinces).features;
		loading = false;
	});

	// Setup zoom when modal opens and svg is available
	$effect(() => {
		if (modalOpen && modalSvgElement && !zoomBehavior) {
			zoomBehavior = zoom()
				.scaleExtent([0.5, 8])
				.on('zoom', (event) => {
					transform = event.transform;
				});

			select(modalSvgElement).call(zoomBehavior);
		}
	});

	function openModal() {
		if (!editable) {
			modalOpen = true;
			// Reset transform when opening modal
			transform = { k: 1, x: 0, y: 0 };
			zoomBehavior = null;
		}
	}

	function closeModal() {
		modalOpen = false;
		zoomBehavior = null;
	}

	function handleKeyDown(e) {
		if (modalOpen && e.key === 'Escape') {
			closeModal();
		}
	}

	function handleBackdropClick(e) {
		if (e.target === e.currentTarget) {
			closeModal();
		}
	}

	function getFill(code) {
		if (excludedRange.has(code)) return '#F08080'; // LightCoral - excluded
		if (inRange.has(code)) return '#228B22'; // ForestGreen - in range
		return '#FFFFFF'; // White - neither
	}

	function handleRegionClick(code) {
		if (editable) {
			onToggle(code);
		}
	}

	function handleRegionKeyDown(e, code) {
		if (editable && (e.key === 'Enter' || e.key === ' ')) {
			e.preventDefault();
			onToggle(code);
		}
	}

	function handleMouseEnter(e, code, name, svgEl) {
		const rect = svgEl?.getBoundingClientRect();
		if (rect) {
			tooltip = {
				show: true,
				x: e.clientX - rect.left,
				y: e.clientY - rect.top - 10,
				text: `${code} - ${name}`
			};
		}
	}

	function handleMouseLeave() {
		tooltip = { ...tooltip, show: false };
	}
</script>

<svelte:window onkeydown={handleKeyDown} />

{#if loading}
	<div class="w-full h-48 flex items-center justify-center text-gray-500">
		Loading map...
	</div>
{:else}
<!-- Static thumbnail map (clickable to open modal, unless editable) -->
<!-- svelte-ignore a11y_no_noninteractive_tabindex -->
<div class="relative border rounded overflow-hidden {editable ? '' : 'cursor-pointer'}" role={editable ? 'presentation' : 'button'} tabindex={editable ? -1 : 0} onclick={openModal} onkeydown={(e) => !editable && (e.key === 'Enter' || e.key === ' ') && openModal()}>
	{#if !editable}
		<div class="absolute top-1 right-1 bg-white/80 text-gray-600 text-xs px-1.5 py-0.5 rounded pointer-events-none">
			Click to expand
		</div>
	{/if}
	<svg
		viewBox="0 0 800 600"
		class="w-full h-auto"
		role="img"
		aria-label="Range map of North America{editable ? '' : ' - click to expand'}"
	>
		<g>
			{#each features as feat}
				{@const postal = feat.properties?.postal ?? ''}
				{@const name = feat.properties?.name ?? 'Unknown'}
				{#if editable}
					<path
						d={path(feat) ?? ''}
						fill={getFill(postal)}
						stroke="black"
						stroke-width="1"
						onclick={(e) => { e.stopPropagation(); handleRegionClick(postal); }}
						onkeydown={(e) => handleRegionKeyDown(e, postal)}
						class="cursor-pointer hover:opacity-80"
						role="button"
						tabindex="0"
						aria-label="Toggle {name}"
					/>
				{:else}
					<path
						d={path(feat) ?? ''}
						fill={getFill(postal)}
						stroke="black"
						stroke-width="1"
						aria-label={name}
					/>
				{/if}
			{/each}
		</g>
	</svg>
</div>

<!-- Modal with zoomable/pannable map -->
{#if modalOpen}
	<!-- svelte-ignore a11y_interactive_supports_focus -->
	<div
		class="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
		onclick={handleBackdropClick}
		onkeydown={() => {}}
		role="dialog"
		aria-modal="true"
		aria-label="Range map expanded view"
	>
		<div class="relative bg-white rounded-lg shadow-xl w-[90vw] h-[85vh] max-w-6xl flex flex-col">
			<!-- Modal header -->
			<div class="flex items-center justify-between px-4 py-3 border-b border-gray-200">
				<div class="text-sm text-gray-600">
					Drag to pan, scroll to zoom
				</div>
				<button
					type="button"
					onclick={closeModal}
					class="p-1 text-gray-500 hover:text-gray-700 hover:bg-gray-100 rounded"
					aria-label="Close modal"
				>
					<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
					</svg>
				</button>
			</div>

			<!-- Modal body with map -->
			<div class="flex-1 relative overflow-hidden">
				<svg
					bind:this={modalSvgElement}
					viewBox="0 0 800 600"
					class="w-full h-full cursor-grab active:cursor-grabbing"
					role="img"
					aria-label="Range map of North America - drag to pan, scroll to zoom"
					preserveAspectRatio="xMidYMid meet"
				>
					<g transform="translate({transform.x}, {transform.y}) scale({transform.k})">
						{#each features as feat}
							{@const postal = feat.properties?.postal ?? ''}
							{@const name = feat.properties?.name ?? 'Unknown'}
							<!-- svelte-ignore a11y_no_static_element_interactions -->
							<path
								d={path(feat) ?? ''}
								fill={getFill(postal)}
								stroke="black"
								stroke-width={1 / transform.k}
								onmouseenter={(e) => handleMouseEnter(e, postal, name, modalSvgElement)}
								onmouseleave={handleMouseLeave}
								aria-label={name}
							/>
						{/each}
					</g>
				</svg>
				{#if tooltip.show}
					<div
						class="absolute bg-gray-800 text-white text-xs px-2 py-1 rounded pointer-events-none whitespace-nowrap z-10"
						style="left: {tooltip.x}px; top: {tooltip.y}px; transform: translate(-50%, -100%);"
					>
						{tooltip.text}
					</div>
				{/if}
			</div>
		</div>
	</div>
{/if}
{/if}
