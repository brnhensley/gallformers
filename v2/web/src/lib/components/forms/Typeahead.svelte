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

<div class="block typeahead-wrapper">
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
			--border-focused="2px solid #661419"
			--list-background="#ffffff"
			--item-color="#1f2937"
			--item-hover-color="#1f2937"
			--item-hover-bg="#e5e7eb"
			--item-is-active-bg="#661419"
			--item-is-active-color="#ffffff"
			--multi-item-bg="#f3e8e8"
			--multi-item-color="#800000"
		>
			<div slot="item" let:item style="color: #1f2937;">
				{getOptionLabel(item)}
			</div>
		</Select>
	</div>
	{#if error}
		<p class="mt-1 text-sm text-red-500">{error}</p>
	{/if}
</div>

<style>
	:global(.svelte-select-list) {
		background: #ffffff !important;
	}
	:global(.svelte-select-list .item) {
		color: #1f2937 !important;
	}
	:global(.svelte-select-list .item.hover:not(.active)) {
		background: #e5e7eb !important;
		color: #1f2937 !important;
	}
	:global(.svelte-select-list .item.active) {
		background: #661419 !important;
		color: #ffffff !important;
	}
</style>
