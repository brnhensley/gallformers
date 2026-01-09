<script lang="ts">
	import { toasts, toast } from './toast';

	const typeClasses: Record<'success' | 'error' | 'info', string> = {
		success: 'bg-green-500',
		error: 'bg-red-500',
		info: 'bg-blue-500'
	};
</script>

<div class="fixed bottom-4 right-4 z-50 space-y-2">
	{#each $toasts as t (t.id)}
		<div
			class="flex items-center gap-2 pl-4 pr-2 py-3 rounded-md text-white shadow-lg {typeClasses[
				t.type
			]}"
			role="alert"
		>
			<span class="flex-1">{t.message}</span>
			<button
				type="button"
				onclick={() => toast.dismiss(t.id)}
				class="p-1 rounded hover:bg-white/20 focus:outline-none focus:ring-2 focus:ring-white/50"
				aria-label="Dismiss"
			>
				<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path
						stroke-linecap="round"
						stroke-linejoin="round"
						stroke-width="2"
						d="M6 18L18 6M6 6l12 12"
					/>
				</svg>
			</button>
		</div>
	{/each}
</div>
