<script module>
	import { defineMeta } from '@storybook/addon-svelte-csf';
	import Input from './Input.svelte';

	const { Story } = defineMeta({
		title: 'Forms/Input',
		component: Input,
		tags: ['autodocs'],
		argTypes: {
			type: {
				control: { type: 'select' },
				options: ['text', 'number', 'email']
			},
			required: { control: 'boolean' },
			disabled: { control: 'boolean' }
		}
	});
</script>

<Story name="Default">
	{#snippet children()}
		<Input label="Username" />
	{/snippet}
</Story>

<Story name="Required">
	{#snippet children()}
		<Input label="Email" type="email" required />
	{/snippet}
</Story>

<Story name="With Error">
	{#snippet children()}
		<Input label="Password" error="Password is required" />
	{/snippet}
</Story>

<Story name="Disabled">
	{#snippet children()}
		<Input label="Disabled Field" disabled value="Cannot edit" />
	{/snippet}
</Story>

<Story name="Number Input">
	{#snippet children()}
		<Input label="Age" type="number" />
	{/snippet}
</Story>

<Story name="All States">
	{#snippet children()}
		<div class="space-y-4 max-w-md">
			<Input label="Normal" />
			<Input label="Required" required />
			<Input label="With Value" value="Some text" />
			<Input label="With Error" error="This field has an error" />
			<Input label="Disabled" disabled value="Read only" />
		</div>
	{/snippet}
</Story>
