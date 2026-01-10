<script>
	/**
	 * InfoTip - Tooltip information icon
	 *
	 * Displays a small info badge that shows a tooltip on hover/focus.
	 * Accessible via keyboard and screen readers.
	 */

	let { text = '', tip = 'i', children } = $props();

	let showTooltip = $state(false);
	let tooltipId = $state(`infotip-${Math.random().toString(36).slice(2, 9)}`);

	function handleFocus() {
		showTooltip = true;
	}

	function handleBlur() {
		showTooltip = false;
	}

	function handleMouseEnter() {
		showTooltip = true;
	}

	function handleMouseLeave() {
		showTooltip = false;
	}

	function handleKeydown(e) {
		if (e.key === 'Escape') {
			showTooltip = false;
		}
	}
</script>

<span class="relative inline-block align-super">
	<button
		type="button"
		class="inline-flex items-center justify-center min-w-[1.25rem] h-5 px-1.5 text-xs font-mono font-medium
               text-gray-600 bg-gray-200 rounded-full
               hover:bg-gray-300 focus:outline-none focus:ring-2 focus:ring-offset-1 focus:ring-blue-500
               transition-colors"
		aria-describedby={tooltipId}
		onfocus={handleFocus}
		onblur={handleBlur}
		onmouseenter={handleMouseEnter}
		onmouseleave={handleMouseLeave}
		onkeydown={handleKeydown}
	>
		{tip}
	</button>

	{#if showTooltip}
		<div
			id={tooltipId}
			role="tooltip"
			class="absolute z-50 bottom-full left-1/2 -translate-x-1/2 mb-2 px-3 py-2 text-sm
                   bg-gray-900 text-white rounded-md shadow-lg max-w-xs whitespace-normal"
		>
			{#if text}
				<p>{text}</p>
			{/if}
			{#if children}
				{@render children()}
			{/if}
			<div
				class="absolute top-full left-1/2 -translate-x-1/2 border-4 border-transparent border-t-gray-900"
			></div>
		</div>
	{/if}
</span>
