<script module>
	import { defineMeta } from '@storybook/addon-svelte-csf';
	import Checkbox from './Checkbox.svelte';

	const { Story } = defineMeta({
		title: 'Forms/Checkbox',
		component: Checkbox,
		tags: ['autodocs'],
		argTypes: {
			checked: { control: 'boolean' },
			disabled: { control: 'boolean' }
		}
	});
</script>

<Story name="Unchecked">
	{#snippet children()}
		<Checkbox label="Accept terms and conditions" />
	{/snippet}
</Story>

<Story name="Checked">
	{#snippet children()}
		<Checkbox label="Subscribe to newsletter" checked />
	{/snippet}
</Story>

<Story name="Disabled">
	{#snippet children()}
		<Checkbox label="This option is disabled" disabled />
	{/snippet}
</Story>

<Story name="Disabled Checked">
	{#snippet children()}
		<Checkbox label="This is locked on" checked disabled />
	{/snippet}
</Story>

<Story name="Multiple Options">
	{#snippet children()}
		<div class="space-y-2">
			<Checkbox label="Option 1" />
			<Checkbox label="Option 2" checked />
			<Checkbox label="Option 3" />
			<Checkbox label="Disabled option" disabled />
		</div>
	{/snippet}
</Story>
