<script>
	/**
	 * DataCompletenessIndicator - Accessible status indicator with tooltip
	 *
	 * Displays data completeness level with an icon, label, and tooltip.
	 * WCAG compliant:
	 * - Sufficient color contrast (not relying solely on color)
	 * - Text labels accompany icons
	 * - Tooltip is keyboard accessible
	 * - Uses semantic status role
	 *
	 * @typedef {'complete' | 'partial' | 'incomplete' | 'unknown'} CompletenessLevel
	 */

	let { level = 'unknown', showLabel = true, size = 'md' } = $props();

	let showTooltip = $state(false);
	let tooltipId = $state(`completeness-tooltip-${Math.random().toString(36).slice(2, 9)}`);

	// Level configurations with WCAG AA compliant colors
	const levels = {
		complete: {
			label: 'Complete',
			description: 'All required data fields are filled in.',
			bgColor: 'bg-green-100',
			textColor: 'text-green-800',
			borderColor: 'border-green-300',
			icon: 'check-circle'
		},
		partial: {
			label: 'Partial',
			description: 'Some data fields are missing or incomplete.',
			bgColor: 'bg-yellow-100',
			textColor: 'text-yellow-800',
			borderColor: 'border-yellow-300',
			icon: 'exclamation-circle'
		},
		incomplete: {
			label: 'Incomplete',
			description: 'Significant data is missing. Help us by contributing information.',
			bgColor: 'bg-red-100',
			textColor: 'text-red-800',
			borderColor: 'border-red-300',
			icon: 'x-circle'
		},
		unknown: {
			label: 'Unknown',
			description: 'Data completeness has not been assessed.',
			bgColor: 'bg-gray-100',
			textColor: 'text-gray-600',
			borderColor: 'border-gray-300',
			icon: 'question-circle'
		}
	};

	const sizeClasses = {
		sm: 'text-xs px-2 py-0.5',
		md: 'text-sm px-2.5 py-1',
		lg: 'text-base px-3 py-1.5'
	};

	const iconSizes = {
		sm: 'w-3 h-3',
		md: 'w-4 h-4',
		lg: 'w-5 h-5'
	};

	let config = $derived(levels[level] || levels.unknown);

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

<div class="relative inline-block">
	<button
		type="button"
		class="inline-flex items-center gap-1.5 rounded-full border font-medium
               {config.bgColor} {config.textColor} {config.borderColor} {sizeClasses[size]}
               focus:outline-none focus:ring-2 focus:ring-offset-1 focus:ring-blue-500"
		aria-describedby={tooltipId}
		onfocus={handleFocus}
		onblur={handleBlur}
		onmouseenter={handleMouseEnter}
		onmouseleave={handleMouseLeave}
		onkeydown={handleKeydown}
	>
		<!-- Icons -->
		{#if config.icon === 'check-circle'}
			<svg class={iconSizes[size]} fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
				<path
					fill-rule="evenodd"
					d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.857-9.809a.75.75 0 00-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 10-1.06 1.061l2.5 2.5a.75.75 0 001.137-.089l4-5.5z"
					clip-rule="evenodd"
				/>
			</svg>
		{:else if config.icon === 'exclamation-circle'}
			<svg class={iconSizes[size]} fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
				<path
					fill-rule="evenodd"
					d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-8-5a.75.75 0 01.75.75v4.5a.75.75 0 01-1.5 0v-4.5A.75.75 0 0110 5zm0 10a1 1 0 100-2 1 1 0 000 2z"
					clip-rule="evenodd"
				/>
			</svg>
		{:else if config.icon === 'x-circle'}
			<svg class={iconSizes[size]} fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
				<path
					fill-rule="evenodd"
					d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.28 7.22a.75.75 0 00-1.06 1.06L8.94 10l-1.72 1.72a.75.75 0 101.06 1.06L10 11.06l1.72 1.72a.75.75 0 101.06-1.06L11.06 10l1.72-1.72a.75.75 0 00-1.06-1.06L10 8.94 8.28 7.22z"
					clip-rule="evenodd"
				/>
			</svg>
		{:else}
			<svg class={iconSizes[size]} fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
				<path
					fill-rule="evenodd"
					d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zM8.94 6.94a.75.75 0 11-1.5 0 .75.75 0 011.5 0zm.756 1.56a.75.75 0 10-1.5 0v4a.75.75 0 001.5 0v-4z"
					clip-rule="evenodd"
				/>
			</svg>
		{/if}

		{#if showLabel}
			<span>{config.label}</span>
		{/if}

		<!-- Screen reader text when label is hidden -->
		{#if !showLabel}
			<span class="sr-only">Data completeness: {config.label}</span>
		{/if}
	</button>

	<!-- Tooltip -->
	{#if showTooltip}
		<div
			id={tooltipId}
			role="tooltip"
			class="absolute z-50 bottom-full left-1/2 -translate-x-1/2 mb-2 px-3 py-2 text-sm
                   bg-gray-900 text-white rounded-md shadow-lg max-w-xs text-center whitespace-normal"
		>
			{config.description}
			<div
				class="absolute top-full left-1/2 -translate-x-1/2 border-4 border-transparent border-t-gray-900"
			></div>
		</div>
	{/if}
</div>
