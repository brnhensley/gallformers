<script>
	import '../app.css';
	import Layout from '$lib/components/layout/Layout.svelte';

	let { children } = $props();
</script>

<svelte:head>
	<title>Gallformers</title>
	<link rel="icon" href="/favicon.png" />
</svelte:head>

<Layout>
	{@render children()}
</Layout>
