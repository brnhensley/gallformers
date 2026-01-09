<script module>
	import { defineMeta } from '@storybook/addon-svelte-csf';
	import Button from './Button.svelte';
	import { fn } from 'storybook/test';

	const { Story } = defineMeta({
		title: 'Forms/Button',
		component: Button,
		tags: ['autodocs'],
		argTypes: {
			variant: {
				control: { type: 'select' },
				options: ['primary', 'secondary', 'danger', 'warning', 'ghost']
			},
			type: {
				control: { type: 'select' },
				options: ['button', 'submit', 'reset']
			},
			disabled: { control: 'boolean' },
			autofocus: { control: 'boolean' }
		},
		args: {
			onclick: fn()
		}
	});
</script>

<Story name="Primary">
	{#snippet children()}
		<Button variant="primary">Primary Button</Button>
	{/snippet}
</Story>

<Story name="Secondary">
	{#snippet children()}
		<Button variant="secondary">Secondary Button</Button>
	{/snippet}
</Story>

<Story name="Danger">
	{#snippet children()}
		<Button variant="danger">Delete</Button>
	{/snippet}
</Story>

<Story name="Warning">
	{#snippet children()}
		<Button variant="warning">Warning</Button>
	{/snippet}
</Story>

<Story name="Ghost">
	{#snippet children()}
		<Button variant="ghost">Ghost Button</Button>
	{/snippet}
</Story>

<Story name="Disabled">
	{#snippet children()}
		<Button disabled>Disabled</Button>
	{/snippet}
</Story>

<Story name="All Variants">
	{#snippet children()}
		<div class="flex flex-wrap gap-4">
			<Button variant="primary">Primary</Button>
			<Button variant="secondary">Secondary</Button>
			<Button variant="danger">Danger</Button>
			<Button variant="warning">Warning</Button>
			<Button variant="ghost">Ghost</Button>
		</div>
	{/snippet}
</Story>
