<script>
	/**
	 * DataCompletenessIndicator - Shows data completeness with emoji and tooltip
	 * Matches V1 behavior: 💯 for complete, ❓ for incomplete
	 */

	let { complete = false, tooltipText = '' } = $props();

	let showTooltip = $state(false);
	let tooltipId = $state(`completeness-tooltip-${Math.random().toString(36).slice(2, 9)}`);

	function handleMouseEnter() {
		showTooltip = true;
	}

	function handleMouseLeave() {
		showTooltip = false;
	}

	function handleFocus() {
		showTooltip = true;
	}

	function handleBlur() {
		showTooltip = false;
	}

	function handleKeydown(e) {
		if (e.key === 'Escape') {
			showTooltip = false;
		}
	}
</script>

<div class="relative inline-block">
	<button
		type="button"
		class="px-2 py-1 text-lg border border-gray-300 rounded bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-1 focus:ring-blue-500"
		aria-describedby={tooltipId}
		onmouseenter={handleMouseEnter}
		onmouseleave={handleMouseLeave}
		onfocus={handleFocus}
		onblur={handleBlur}
		onkeydown={handleKeydown}
	>
		{complete ? '💯' : '❓'}
		<span class="sr-only">Data completeness: {complete ? 'Complete' : 'Incomplete'}</span>
	</button>

	<!-- Tooltip positioned to the right like V1 -->
	{#if showTooltip && tooltipText}
		<div
			id={tooltipId}
			role="tooltip"
			class="absolute z-50 left-full top-1/2 -translate-y-1/2 ml-2 px-3 py-2 text-sm
                   bg-gray-900 text-white rounded-md shadow-lg w-64 whitespace-normal"
		>
			{tooltipText}
			<!-- Arrow pointing left -->
			<div
				class="absolute right-full top-1/2 -translate-y-1/2 border-4 border-transparent border-r-gray-900"
			></div>
		</div>
	{/if}
</div>
