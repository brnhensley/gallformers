<script>
	import ToastContainer from './ToastContainer.svelte';
	import { toast } from './toast.js';
	import Button from '../forms/Button.svelte';

	let { variant = 'all' } = $props();
</script>

<div class="space-y-4">
	{#if variant === 'all'}
		<p class="text-sm text-gray-600">Click the buttons to trigger toasts (bottom-right corner):</p>
		<div class="flex flex-wrap gap-2">
			<Button variant="primary" onclick={() => toast.success('Changes saved successfully!')}>
				Success Toast
			</Button>
			<Button variant="danger" onclick={() => toast.error('Failed to save changes.')}>
				Error Toast
			</Button>
			<Button variant="secondary" onclick={() => toast.info('New updates available.')}>
				Info Toast
			</Button>
		</div>
	{:else if variant === 'success'}
		<Button onclick={() => toast.success('Species created successfully!')}>Show Success</Button>
	{:else if variant === 'error'}
		<Button variant="danger" onclick={() => toast.error('Network error. Please try again.')}>
			Show Error
		</Button>
	{:else if variant === 'info'}
		<Button variant="secondary" onclick={() => toast.info('Tip: Use keyboard shortcuts.')}>
			Show Info
		</Button>
	{:else if variant === 'multiple'}
		<Button
			onclick={() => {
				toast.success('First toast');
				setTimeout(() => toast.info('Second toast'), 300);
				setTimeout(() => toast.error('Third toast'), 600);
			}}
		>
			Show Multiple Toasts
		</Button>
	{/if}
</div>
<ToastContainer />
