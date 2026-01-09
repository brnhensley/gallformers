<script module>
	import { defineMeta } from '@storybook/addon-svelte-csf';
	import ToastDemo from './ToastDemo.svelte';

	const { Story } = defineMeta({
		title: 'Feedback/ToastContainer',
		component: ToastDemo,
		tags: ['autodocs']
	});
</script>

{#snippet template(args)}
	<ToastDemo {...args} />
{/snippet}

<Story name="Interactive Demo" args={{ variant: 'all' }} {template} />

<Story name="Success" args={{ variant: 'success' }} {template} />

<Story name="Error" args={{ variant: 'error' }} {template} />

<Story name="Info" args={{ variant: 'info' }} {template} />

<Story name="Multiple Toasts" args={{ variant: 'multiple' }} {template} />
