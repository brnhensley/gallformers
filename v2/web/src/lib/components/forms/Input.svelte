<script>
	let {
		value = $bindable(''),
		label,
		type = 'text',
		required = false,
		disabled = false,
		error = undefined
	} = $props();
</script>

<label class="block">
	<span class="block text-sm font-medium text-gray-700">
		{label}{#if required}<span class="text-red-500">*</span>{/if}
	</span>
	<input
		{type}
		bind:value
		{required}
		{disabled}
		class="mt-1 block w-full rounded-md border-gray-300 shadow-sm
           focus:border-gf-maroon focus:ring-gf-maroon
           {error ? 'border-red-500' : ''}"
	/>
	{#if error}
		<p class="mt-1 text-sm text-red-500">{error}</p>
	{/if}
</label>
