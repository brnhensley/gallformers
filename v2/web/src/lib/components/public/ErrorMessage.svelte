<script>
	/**
	 * ErrorMessage - User-friendly error display with retry option
	 *
	 * Shows an error message with an optional retry button.
	 * Designed for data fetching errors and other recoverable failures.
	 */

	let {
		title = 'Something went wrong',
		message = 'An unexpected error occurred. Please try again.',
		showRetry = true,
		retryLabel = 'Try again',
		onretry,
		variant = 'error'
	} = $props();

	const variants = {
		error: {
			bg: 'bg-red-50',
			border: 'border-red-200',
			iconColor: 'text-red-500',
			titleColor: 'text-red-800',
			textColor: 'text-red-700',
			buttonBg: 'bg-red-100 hover:bg-red-200',
			buttonText: 'text-red-800'
		},
		warning: {
			bg: 'bg-yellow-50',
			border: 'border-yellow-200',
			iconColor: 'text-yellow-500',
			titleColor: 'text-yellow-800',
			textColor: 'text-yellow-700',
			buttonBg: 'bg-yellow-100 hover:bg-yellow-200',
			buttonText: 'text-yellow-800'
		},
		info: {
			bg: 'bg-blue-50',
			border: 'border-blue-200',
			iconColor: 'text-blue-500',
			titleColor: 'text-blue-800',
			textColor: 'text-blue-700',
			buttonBg: 'bg-blue-100 hover:bg-blue-200',
			buttonText: 'text-blue-800'
		}
	};

	let config = $derived(variants[variant] || variants.error);

	function handleRetry() {
		if (onretry) {
			onretry();
		}
	}
</script>

<div class="rounded-lg border p-4 {config.bg} {config.border}" role="alert">
	<div class="flex items-start gap-3">
		<!-- Error Icon -->
		<div class="flex-shrink-0">
			{#if variant === 'error'}
				<svg class="w-6 h-6 {config.iconColor}" fill="none" viewBox="0 0 24 24" stroke="currentColor">
					<path
						stroke-linecap="round"
						stroke-linejoin="round"
						stroke-width="2"
						d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
					/>
				</svg>
			{:else if variant === 'warning'}
				<svg class="w-6 h-6 {config.iconColor}" fill="none" viewBox="0 0 24 24" stroke="currentColor">
					<path
						stroke-linecap="round"
						stroke-linejoin="round"
						stroke-width="2"
						d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
					/>
				</svg>
			{:else}
				<svg class="w-6 h-6 {config.iconColor}" fill="none" viewBox="0 0 24 24" stroke="currentColor">
					<path
						stroke-linecap="round"
						stroke-linejoin="round"
						stroke-width="2"
						d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
					/>
				</svg>
			{/if}
		</div>

		<!-- Content -->
		<div class="flex-1 min-w-0">
			<h3 class="text-sm font-semibold {config.titleColor}">{title}</h3>
			<p class="mt-1 text-sm {config.textColor}">{message}</p>

			{#if showRetry && onretry}
				<div class="mt-3">
					<button
						type="button"
						onclick={handleRetry}
						class="inline-flex items-center gap-2 px-3 py-1.5 text-sm font-medium rounded-md
                           {config.buttonBg} {config.buttonText} transition-colors
                           focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
					>
						<svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path
								stroke-linecap="round"
								stroke-linejoin="round"
								stroke-width="2"
								d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
							/>
						</svg>
						{retryLabel}
					</button>
				</div>
			{/if}
		</div>
	</div>
</div>
