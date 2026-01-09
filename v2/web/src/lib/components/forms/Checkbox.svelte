<script lang="ts">
	let {
		checked = $bindable(false),
		label,
		disabled = false
	}: {
		checked?: boolean;
		label: string;
		disabled?: boolean;
	} = $props();
</script>

<label class="flex items-center space-x-2">
	<input
		type="checkbox"
		bind:checked
		{disabled}
		class="rounded border-gray-300 text-gf-maroon
           focus:ring-gf-maroon"
	/>
	<span class="text-sm text-gray-700">{label}</span>
</label>
