<script>
	let {
		selected = $bindable([]),
		options,
		labelKey = 'label',
		valueKey = 'id',
		label,
		required = false,
		error = undefined
	} = $props();

	function toggle(opt) {
		const idx = selected.findIndex((s) => s[valueKey] === opt[valueKey]);
		if (idx >= 0) {
			selected = selected.filter((_, i) => i !== idx);
		} else {
			selected = [...selected, opt];
		}
	}

	function isSelected(opt) {
		return selected.some((s) => s[valueKey] === opt[valueKey]);
	}
</script>

<fieldset>
	<legend class="block text-sm font-medium text-gray-700">
		{label}{#if required}<span class="text-red-500">*</span>{/if}
	</legend>
	<div class="mt-2 flex flex-wrap gap-2">
		{#each options as opt}
			<button
				type="button"
				onclick={() => toggle(opt)}
				class="px-3 py-1 rounded-full text-sm border
               {isSelected(opt)
					? 'bg-gf-maroon text-white border-gf-maroon'
					: 'bg-white text-gray-700 border-gray-300 hover:border-gf-maroon'}"
			>
				{opt[labelKey]}
			</button>
		{/each}
	</div>
</fieldset>
{#if error}
	<p class="mt-1 text-sm text-red-500">{error}</p>
{/if}
