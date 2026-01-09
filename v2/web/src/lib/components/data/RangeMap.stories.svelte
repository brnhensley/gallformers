<script module>
	import { defineMeta } from '@storybook/addon-svelte-csf';
	import RangeMap from './RangeMap.svelte';

	const { Story } = defineMeta({
		title: 'Data/RangeMap',
		component: RangeMap,
		tags: ['autodocs']
	});
</script>

<script>
	let editableRange = $state(new Set(['CA', 'OR', 'WA']));

	function handleToggle(code) {
		if (editableRange.has(code)) {
			editableRange = new Set([...editableRange].filter((c) => c !== code));
		} else {
			editableRange = new Set([...editableRange, code]);
		}
	}
</script>

{#snippet template(args)}
	<div class="max-w-2xl">
		<RangeMap {...args} />
	</div>
{/snippet}

<Story name="Default (Empty)" args={{ inRange: new Set() }} {template} />

<Story name="Western US" args={{ inRange: new Set(['CA', 'OR', 'WA', 'NV', 'AZ']) }} {template} />

<Story name="Eastern US" args={{ inRange: new Set(['NY', 'PA', 'NJ', 'CT', 'MA', 'VT', 'NH', 'ME', 'VA', 'MD']) }} {template} />

<Story name="With Excluded Range" args={{ inRange: new Set(['TX', 'OK', 'KS', 'NE', 'SD', 'ND']), excludedRange: new Set(['LA', 'AR', 'MO']) }} {template} />

<Story name="Canada" args={{ inRange: new Set(['BC', 'AB', 'SK', 'MB', 'ON', 'QC']) }} {template} />

<Story name="Editable">
	{#snippet template()}
		<div class="max-w-2xl">
			<p class="mb-2 text-sm text-gray-600">Click states/provinces to toggle selection:</p>
			<RangeMap inRange={editableRange} editable onToggle={handleToggle} />
			<p class="mt-2 text-sm text-gray-600">
				Selected: {[...editableRange].sort().join(', ') || 'None'}
			</p>
		</div>
	{/snippet}
</Story>

<Story name="Full Coverage" args={{ inRange: new Set(['AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA', 'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD', 'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ', 'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC', 'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY', 'BC', 'AB', 'SK', 'MB', 'ON', 'QC', 'NB', 'NS', 'PE', 'NL']) }} {template} />
