<script>
	let {
		variant = 'primary',
		type = 'button',
		disabled = false,
		autofocus = false,
		onclick,
		children
	} = $props();

	let buttonEl;

	// Focus on mount when autofocus is true
	$effect(() => {
		if (autofocus && buttonEl) {
			setTimeout(() => buttonEl?.focus(), 0);
		}
	});

	const variantClasses = {
		primary: 'bg-gf-maroon text-white hover:bg-gf-maroon-dark',
		secondary: 'bg-white text-gray-700 border border-gray-300 hover:bg-gray-50',
		danger: 'bg-red-600 text-white hover:bg-red-700',
		warning: 'bg-yellow-500 text-white hover:bg-yellow-600',
		ghost: 'text-gf-maroon hover:bg-gf-maroon/10'
	};
</script>

<button
	bind:this={buttonEl}
	{type}
	{disabled}
	{onclick}
	class="px-4 py-2 rounded-md font-medium transition-colors
         focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gf-maroon
         disabled:opacity-50 disabled:cursor-not-allowed
         {variantClasses[variant]}"
>
	{@render children()}
</button>
