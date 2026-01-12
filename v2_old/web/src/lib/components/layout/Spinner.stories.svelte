<script module>
	import { defineMeta } from '@storybook/addon-svelte-csf';
	import Spinner from './Spinner.svelte';

	const { Story } = defineMeta({
		title: 'Layout/Spinner',
		component: Spinner,
		tags: ['autodocs'],
		argTypes: {
			size: {
				control: { type: 'select' },
				options: ['sm', 'md', 'lg']
			}
		}
	});
</script>

<Story name="Small">
	{#snippet children()}
		<Spinner size="sm" />
	{/snippet}
</Story>

<Story name="Medium">
	{#snippet children()}
		<Spinner size="md" />
	{/snippet}
</Story>

<Story name="Large">
	{#snippet children()}
		<Spinner size="lg" />
	{/snippet}
</Story>

<Story name="All Sizes">
	{#snippet children()}
		<div class="flex items-center gap-8">
			<div class="text-center">
				<Spinner size="sm" />
				<p class="mt-2 text-sm text-gray-600">Small</p>
			</div>
			<div class="text-center">
				<Spinner size="md" />
				<p class="mt-2 text-sm text-gray-600">Medium</p>
			</div>
			<div class="text-center">
				<Spinner size="lg" />
				<p class="mt-2 text-sm text-gray-600">Large</p>
			</div>
		</div>
	{/snippet}
</Story>

<Story name="Loading State Example">
	{#snippet children()}
		<div class="flex items-center gap-2 p-4 bg-gray-100 rounded">
			<Spinner size="sm" />
			<span class="text-gray-700">Loading data...</span>
		</div>
	{/snippet}
</Story>

<Story name="Centered Loading">
	{#snippet children()}
		<div class="flex justify-center items-center h-32 bg-gray-50 rounded border">
			<div class="text-center">
				<Spinner size="lg" />
				<p class="mt-3 text-gray-600">Please wait...</p>
			</div>
		</div>
	{/snippet}
</Story>
