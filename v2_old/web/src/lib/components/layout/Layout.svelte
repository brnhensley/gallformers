<script>
	import Header from './Header.svelte';
	import Footer from './Footer.svelte';

	let { children } = $props();
</script>

<div class="flex min-h-screen flex-col">
	<Header />

	<main class="flex-1 pb-32">
		{@render children?.()}
	</main>

	<Footer />
</div>
