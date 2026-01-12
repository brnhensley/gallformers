<script module>
	import { defineMeta } from '@storybook/addon-svelte-csf';
	import Layout from './Layout.svelte';

	const { Story } = defineMeta({
		title: 'Layout/Layout',
		component: Layout,
		tags: ['autodocs'],
		parameters: {
			layout: 'fullscreen'
		}
	});
</script>

<Story name="Default">
	<Layout>
		<div class="p-8">
			<h1 class="text-2xl font-bold">Page Content</h1>
			<p class="mt-4">This is the main content area wrapped by the Layout component.</p>
		</div>
	</Layout>
</Story>

<Story name="With Long Content">
	<Layout>
		<div class="p-8">
			<h1 class="text-2xl font-bold">Long Page Content</h1>
			{#each Array(20) as _, i}
				<p class="mt-4">Paragraph {i + 1}: Lorem ipsum dolor sit amet, consectetur adipiscing elit.</p>
			{/each}
		</div>
	</Layout>
</Story>
