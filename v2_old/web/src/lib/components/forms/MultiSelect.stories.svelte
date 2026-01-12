<script module>
	import { defineMeta } from '@storybook/addon-svelte-csf';
	import MultiSelect from './MultiSelect.svelte';

	const { Story } = defineMeta({
		title: 'Forms/MultiSelect',
		component: MultiSelect,
		tags: ['autodocs'],
		argTypes: {
			required: { control: 'boolean' }
		}
	});
</script>

<script>
	const tagOptions = [
		{ id: 1, label: 'JavaScript' },
		{ id: 2, label: 'TypeScript' },
		{ id: 3, label: 'Python' },
		{ id: 4, label: 'Rust' },
		{ id: 5, label: 'Go' }
	];

	const colorOptions = [
		{ id: 'red', label: 'Red' },
		{ id: 'green', label: 'Green' },
		{ id: 'blue', label: 'Blue' },
		{ id: 'yellow', label: 'Yellow' }
	];

	const manyOptions = Array.from({ length: 20 }, (_, i) => ({
		id: i + 1,
		label: `Option ${i + 1}`
	}));
</script>

<Story name="Default">
	{#snippet children()}
		<MultiSelect label="Select Languages" options={tagOptions} />
	{/snippet}
</Story>

<Story name="With Preselected">
	{#snippet children()}
		<MultiSelect
			label="Favorite Colors"
			options={colorOptions}
			selected={[
				{ id: 'red', label: 'Red' },
				{ id: 'blue', label: 'Blue' }
			]}
		/>
	{/snippet}
</Story>

<Story name="Required">
	{#snippet children()}
		<MultiSelect label="Required Tags" options={tagOptions} required />
	{/snippet}
</Story>

<Story name="With Error">
	{#snippet children()}
		<MultiSelect label="Categories" options={tagOptions} error="Select at least one category" />
	{/snippet}
</Story>

<Story name="Many Options">
	{#snippet children()}
		<MultiSelect label="Choose Multiple" options={manyOptions} />
	{/snippet}
</Story>
