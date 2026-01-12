<script module>
	import { defineMeta } from '@storybook/addon-svelte-csf';
	import ModalDemo from './ModalDemo.svelte';

	const { Story } = defineMeta({
		title: 'Layout/Modal',
		component: ModalDemo,
		tags: ['autodocs']
	});
</script>

{#snippet template(args)}
	<ModalDemo {...args} />
{/snippet}

<Story name="Basic" args={{ title: 'Basic Modal', variant: 'basic' }} {template} />

<Story name="With Form" args={{ title: 'Edit Species', variant: 'form' }} {template} />

<Story name="Long Content" args={{ title: 'Terms and Conditions', variant: 'long' }} {template} />
