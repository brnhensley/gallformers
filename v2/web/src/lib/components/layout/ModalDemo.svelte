<script lang="ts">
	import Modal from './Modal.svelte';
	import Button from '../forms/Button.svelte';

	let { title = 'Modal Title', variant = 'basic' }: { title?: string; variant?: 'basic' | 'form' | 'long' } = $props();

	let open = $state(false);
</script>

<Button onclick={() => (open = true)}>Open Modal</Button>
<Modal bind:open {title}>
	{#if variant === 'basic'}
		<p class="text-gray-600 mb-4">This is a basic modal with some content.</p>
		<div class="flex justify-end">
			<Button onclick={() => (open = false)}>Close</Button>
		</div>
	{:else if variant === 'form'}
		<form class="space-y-4">
			<div>
				<label class="block text-sm font-medium text-gray-700">Name</label>
				<input type="text" class="mt-1 block w-full rounded-md border-gray-300" value="Andricus" />
			</div>
			<div>
				<label class="block text-sm font-medium text-gray-700">Description</label>
				<textarea class="mt-1 block w-full rounded-md border-gray-300" rows="3"></textarea>
			</div>
		</form>
		<div class="flex justify-end gap-2 mt-6">
			<Button variant="secondary" onclick={() => (open = false)}>Cancel</Button>
			<Button onclick={() => (open = false)}>Save</Button>
		</div>
	{:else if variant === 'long'}
		<div class="text-gray-600 space-y-4 max-h-96 overflow-y-auto">
			<p>Lorem ipsum dolor sit amet, consectetur adipiscing elit.</p>
			<p>Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris.</p>
			<p>Duis aute irure dolor in reprehenderit in voluptate velit esse cillum.</p>
			<p>Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia.</p>
		</div>
		<div class="flex justify-end mt-6">
			<Button onclick={() => (open = false)}>I Agree</Button>
		</div>
	{/if}
</Modal>
