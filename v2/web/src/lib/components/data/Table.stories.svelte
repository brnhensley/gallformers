<script module>
	import { defineMeta } from '@storybook/addon-svelte-csf';
	import Table from './Table.svelte';

	const { Story } = defineMeta({
		title: 'Data/Table',
		component: Table,
		tags: ['autodocs']
	});
</script>

<script>
	const speciesData = [
		{ id: 1, name: 'Andricus quercuscalifornicus', family: 'Cynipidae', host: 'Quercus lobata' },
		{ id: 2, name: 'Belonocnema treatae', family: 'Cynipidae', host: 'Quercus virginiana' },
		{ id: 3, name: 'Callirhytis quercuspomiformis', family: 'Cynipidae', host: 'Quercus alba' },
		{ id: 4, name: 'Disholcaspis quercusmamma', family: 'Cynipidae', host: 'Quercus macrocarpa' },
		{ id: 5, name: 'Neuroterus saltatorius', family: 'Cynipidae', host: 'Quercus garryana' }
	];

	const columns = [
		{ key: 'name', label: 'Species Name', sortable: true },
		{ key: 'family', label: 'Family', sortable: true },
		{ key: 'host', label: 'Host Plant', sortable: true }
	];

	const paginatedData = Array.from({ length: 100 }, (_, i) => ({
		id: i + 1,
		name: `Species ${i + 1}`,
		family: 'Cynipidae',
		host: `Host ${i + 1}`
	}));

	let currentPage = $state(1);

	function handlePageChange(page) {
		currentPage = page;
	}

	const customColumns = [
		{ key: 'name', label: 'Species', sortable: true },
		{ key: 'family', label: 'Family', render: (row) => `[${row.family}]` },
		{ key: 'host', label: 'Host', render: (row) => row.host.replace('Quercus', 'Q.') }
	];

	const largeColumns = [
		{ key: 'id', label: 'ID', sortable: true },
		{ key: 'name', label: 'Name', sortable: true },
		{ key: 'family', label: 'Family' },
		{ key: 'host', label: 'Host' }
	];
</script>

{#snippet template(args)}
	<Table {...args} />
{/snippet}

<Story name="Basic" args={{ data: speciesData, columns }} {template} />

<Story name="Sortable" args={{ data: speciesData, columns, onsort: (key) => console.log('Sort:', key) }} {template} />

<Story name="With Pagination">
	{#snippet template()}
		<Table
			data={paginatedData.slice((currentPage - 1) * 10, currentPage * 10)}
			{columns}
			page={currentPage}
			pageSize={10}
			totalCount={paginatedData.length}
			onpagechange={handlePageChange}
		/>
	{/snippet}
</Story>

<Story name="Custom Render" args={{ data: speciesData, columns: customColumns }} {template} />

<Story name="Empty State" args={{ data: [], columns }} {template} />

<Story name="Large Dataset" args={{ data: paginatedData.slice(0, 25), columns: largeColumns, page: 1, pageSize: 25, totalCount: 100 }} {template} />
