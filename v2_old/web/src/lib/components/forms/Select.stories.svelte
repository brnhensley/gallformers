<script module>
	import { defineMeta } from '@storybook/addon-svelte-csf';
	import Select from './Select.svelte';

	const { Story } = defineMeta({
		title: 'Forms/Select',
		component: Select,
		tags: ['autodocs'],
		argTypes: {
			required: { control: 'boolean' },
			disabled: { control: 'boolean' }
		}
	});
</script>

<script>
	const colorOptions = [
		{ label: 'Red', value: 'red' },
		{ label: 'Green', value: 'green' },
		{ label: 'Blue', value: 'blue' }
	];

	const stateOptions = [
		{ label: 'California', value: 'CA' },
		{ label: 'Texas', value: 'TX' },
		{ label: 'New York', value: 'NY' },
		{ label: 'Florida', value: 'FL' }
	];

	const customOptions = [
		{ name: 'Apple', id: 1 },
		{ name: 'Banana', id: 2 },
		{ name: 'Cherry', id: 3 }
	];
</script>

<Story name="Default">
	{#snippet children()}
		<Select label="Favorite Color" options={colorOptions} />
	{/snippet}
</Story>

<Story name="Required">
	{#snippet children()}
		<Select label="State" options={stateOptions} required />
	{/snippet}
</Story>

<Story name="With Error">
	{#snippet children()}
		<Select label="Category" options={colorOptions} error="Please select a category" />
	{/snippet}
</Story>

<Story name="Disabled">
	{#snippet children()}
		<Select label="Locked Selection" options={colorOptions} disabled />
	{/snippet}
</Story>

<Story name="With Preselected Value">
	{#snippet children()}
		<Select label="Color" options={colorOptions} value="green" />
	{/snippet}
</Story>

<Story name="Custom Keys">
	{#snippet children()}
		<Select label="Fruit" options={customOptions} optionLabel="name" optionValue="id" />
	{/snippet}
</Story>
