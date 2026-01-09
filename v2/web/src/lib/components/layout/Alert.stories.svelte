<script module>
	import { defineMeta } from '@storybook/addon-svelte-csf';
	import Alert from './Alert.svelte';

	const { Story } = defineMeta({
		title: 'Layout/Alert',
		component: Alert,
		tags: ['autodocs'],
		argTypes: {
			variant: {
				control: { type: 'select' },
				options: ['info', 'warning', 'error', 'success']
			}
		}
	});
</script>

<Story name="Info">
	{#snippet children()}
		<Alert variant="info">This is an informational message.</Alert>
	{/snippet}
</Story>

<Story name="Success">
	{#snippet children()}
		<Alert variant="success">Your changes have been saved successfully!</Alert>
	{/snippet}
</Story>

<Story name="Warning">
	{#snippet children()}
		<Alert variant="warning">Please review your input before submitting.</Alert>
	{/snippet}
</Story>

<Story name="Error">
	{#snippet children()}
		<Alert variant="error">An error occurred while processing your request.</Alert>
	{/snippet}
</Story>

<Story name="With Long Content">
	{#snippet children()}
		<Alert variant="info">
			This is a longer alert message that contains multiple sentences. It demonstrates how the
			component handles longer content. The alert should expand vertically to accommodate all the
			text while maintaining proper padding and styling.
		</Alert>
	{/snippet}
</Story>

<Story name="All Variants">
	{#snippet children()}
		<div class="space-y-4">
			<Alert variant="info">Info: This is an informational message.</Alert>
			<Alert variant="success">Success: Operation completed successfully!</Alert>
			<Alert variant="warning">Warning: Please proceed with caution.</Alert>
			<Alert variant="error">Error: Something went wrong.</Alert>
		</div>
	{/snippet}
</Story>
