<script>
	import Select from 'svelte-select';

	let {
		selected = $bindable(null),
		label,
		searchFn,
		labelKey = 'name',
		multiple = false,
		creatable = false,
		required = false,
		error = undefined
	} = $props();

	// Generate unique ID for accessibility
	const labelId = `typeahead-label-${Math.random().toString(36).slice(2, 9)}`;

	function getOptionLabel(opt) {
		if (opt && typeof opt === 'object' && labelKey in opt) {
			return String(opt[labelKey]);
		}
		return String(opt);
	}

	// Extra props for svelte-select
	const extraProps = $derived({ creatable });
</script>

<div class="block">
	<span id={labelId} class="block text-sm font-medium text-gray-700">
		{label}{#if required}<span class="text-red-500">*</span>{/if}
	</span>
	<div class="mt-1">
		<Select
			bind:value={selected}
			loadOptions={searchFn}
			{multiple}
			{...extraProps}
			{getOptionLabel}
			placeholder="Type to search..."
			--border-radius="0.375rem"
			--border-focused="2px solid var(--gf-maroon)"
			--item-is-active-bg="var(--gf-maroon)"
			--multi-item-bg="#f3e8e8"
			--multi-item-color="#800000"
		/>
	</div>
	{#if error}
		<p class="mt-1 text-sm text-red-500">{error}</p>
	{/if}
</div>
