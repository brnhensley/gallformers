<script module>
	import { defineMeta } from '@storybook/addon-svelte-csf';
	import Textarea from './Textarea.svelte';

	const { Story } = defineMeta({
		title: 'Forms/Textarea',
		component: Textarea,
		tags: ['autodocs'],
		argTypes: {
			rows: { control: { type: 'number', min: 1, max: 20 } },
			required: { control: 'boolean' },
			disabled: { control: 'boolean' }
		}
	});
</script>

<Story name="Default">
	{#snippet children()}
		<Textarea label="Description" />
	{/snippet}
</Story>

<Story name="With Placeholder Text">
	{#snippet children()}
		<Textarea label="Notes" value="Enter your notes here..." />
	{/snippet}
</Story>

<Story name="Required">
	{#snippet children()}
		<Textarea label="Comments" required />
	{/snippet}
</Story>

<Story name="More Rows">
	{#snippet children()}
		<Textarea label="Long Description" rows={8} />
	{/snippet}
</Story>

<Story name="With Error">
	{#snippet children()}
		<Textarea label="Bio" error="Bio cannot exceed 500 characters" />
	{/snippet}
</Story>

<Story name="Disabled">
	{#snippet children()}
		<Textarea label="Read Only" disabled value="This content cannot be edited." />
	{/snippet}
</Story>

<Story name="All States">
	{#snippet children()}
		<div class="space-y-4 max-w-lg">
			<Textarea label="Normal" />
			<Textarea label="Required" required />
			<Textarea label="With Error" error="This field has an error" />
			<Textarea label="Disabled" disabled value="Cannot edit" />
		</div>
	{/snippet}
</Story>
