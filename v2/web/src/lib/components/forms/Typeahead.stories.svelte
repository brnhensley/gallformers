<script module>
	import { defineMeta } from '@storybook/addon-svelte-csf';
	import Typeahead from './Typeahead.svelte';

	const { Story } = defineMeta({
		title: 'Forms/Typeahead',
		component: Typeahead,
		tags: ['autodocs'],
		argTypes: {
			multiple: { control: 'boolean' },
			creatable: { control: 'boolean' },
			required: { control: 'boolean' }
		}
	});
</script>

<script>
	const mockData = [
		{ id: 1, name: 'Apple' },
		{ id: 2, name: 'Banana' },
		{ id: 3, name: 'Cherry' },
		{ id: 4, name: 'Date' },
		{ id: 5, name: 'Elderberry' },
		{ id: 6, name: 'Fig' },
		{ id: 7, name: 'Grape' }
	];

	async function searchFruits(query) {
		await new Promise((r) => setTimeout(r, 200));
		if (!query) return mockData.slice(0, 5);
		return mockData.filter((f) => f.name.toLowerCase().includes(query.toLowerCase()));
	}

	const speciesData = [
		{ id: 1, name: 'Andricus quercuscalifornicus' },
		{ id: 2, name: 'Andricus kingi' },
		{ id: 3, name: 'Belonocnema treatae' },
		{ id: 4, name: 'Callirhytis quercuspomiformis' },
		{ id: 5, name: 'Disholcaspis quercusmamma' }
	];

	async function searchSpecies(query) {
		await new Promise((r) => setTimeout(r, 300));
		if (!query) return speciesData;
		return speciesData.filter((s) => s.name.toLowerCase().includes(query.toLowerCase()));
	}
</script>

<Story name="Default">
	{#snippet children()}
		<div class="max-w-md">
			<Typeahead label="Search Fruits" searchFn={searchFruits} />
		</div>
	{/snippet}
</Story>

<Story name="Multiple Selection">
	{#snippet children()}
		<div class="max-w-md">
			<Typeahead label="Select Multiple Fruits" searchFn={searchFruits} multiple />
		</div>
	{/snippet}
</Story>

<Story name="Creatable">
	{#snippet children()}
		<div class="max-w-md">
			<Typeahead label="Tags (can create new)" searchFn={searchFruits} creatable />
		</div>
	{/snippet}
</Story>

<Story name="Required">
	{#snippet children()}
		<div class="max-w-md">
			<Typeahead label="Species (required)" searchFn={searchSpecies} required />
		</div>
	{/snippet}
</Story>

<Story name="With Error">
	{#snippet children()}
		<div class="max-w-md">
			<Typeahead label="Category" searchFn={searchFruits} error="Please select a category" />
		</div>
	{/snippet}
</Story>

<Story name="Species Search">
	{#snippet children()}
		<div class="max-w-md">
			<Typeahead label="Search Gall Species" searchFn={searchSpecies} />
		</div>
	{/snippet}
</Story>
