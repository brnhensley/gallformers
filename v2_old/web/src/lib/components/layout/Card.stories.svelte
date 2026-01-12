<script module>
	import { defineMeta } from '@storybook/addon-svelte-csf';
	import Card from './Card.svelte';

	const { Story } = defineMeta({
		title: 'Layout/Card',
		component: Card,
		tags: ['autodocs']
	});
</script>

<script>
	import Button from '../forms/Button.svelte';
</script>

<Story name="Default">
	{#snippet children()}
		<Card>
			<p>This is some content inside a card.</p>
		</Card>
	{/snippet}
</Story>

<Story name="With Title">
	{#snippet children()}
		<Card title="Card Title">
			<p>This card has a title and some content below it.</p>
		</Card>
	{/snippet}
</Story>

<Story name="Species Card">
	{#snippet children()}
		<div class="max-w-md">
			<Card title="Andricus quercuscalifornicus">
				<p class="text-gray-600 mb-4">
					The California oak gall wasp, one of the most common gall-forming insects on oaks in
					California.
				</p>
				<div class="flex gap-2">
					<Button variant="primary">View Details</Button>
					<Button variant="secondary">Edit</Button>
				</div>
			</Card>
		</div>
	{/snippet}
</Story>

<Story name="Multiple Cards">
	{#snippet children()}
		<div class="grid grid-cols-1 md:grid-cols-2 gap-4 max-w-2xl">
			<Card title="First Card">
				<p>Content for the first card.</p>
			</Card>
			<Card title="Second Card">
				<p>Content for the second card.</p>
			</Card>
			<Card title="Third Card">
				<p>Content for the third card.</p>
			</Card>
			<Card title="Fourth Card">
				<p>Content for the fourth card.</p>
			</Card>
		</div>
	{/snippet}
</Story>

<Story name="No Title">
	{#snippet children()}
		<div class="max-w-md">
			<Card>
				<div class="text-center">
					<h4 class="text-lg font-medium">Custom Header</h4>
					<p class="text-gray-600 mt-2">
						Sometimes you want full control over the card content without using the built-in title.
					</p>
				</div>
			</Card>
		</div>
	{/snippet}
</Story>
