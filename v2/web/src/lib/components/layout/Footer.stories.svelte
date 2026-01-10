<script module>
	import { defineMeta } from '@storybook/addon-svelte-csf';
	import Footer from './Footer.svelte';

	const { Story } = defineMeta({
		title: 'Layout/Footer',
		component: Footer,
		tags: ['autodocs'],
		parameters: {
			layout: 'fullscreen'
		}
	});
</script>

<Story name="Default">
	<Footer />
</Story>
