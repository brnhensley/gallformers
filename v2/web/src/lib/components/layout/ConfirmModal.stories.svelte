<script module>
	import { defineMeta } from '@storybook/addon-svelte-csf';
	import ConfirmModalDemo from './ConfirmModalDemo.svelte';

	const { Story } = defineMeta({
		title: 'Layout/ConfirmModal',
		component: ConfirmModalDemo,
		tags: ['autodocs']
	});
</script>

{#snippet template(args)}
	<ConfirmModalDemo {...args} />
{/snippet}

<Story
	name="Danger"
	args={{
		buttonLabel: 'Delete Item',
		buttonVariant: 'danger',
		title: 'Delete Species',
		message: 'Are you sure you want to delete this species? This action cannot be undone.',
		variant: 'danger',
		confirmLabel: 'Delete'
	}}
	{template}
/>

<Story
	name="Warning"
	args={{
		buttonLabel: 'Reset Data',
		buttonVariant: 'warning',
		title: 'Reset All Data',
		message: 'This will reset all your changes to the default state. Do you want to continue?',
		variant: 'warning',
		confirmLabel: 'Reset'
	}}
	{template}
/>

<Story
	name="Custom Labels"
	args={{
		buttonLabel: 'Publish',
		buttonVariant: 'primary',
		title: 'Publish Changes',
		message: 'Are you sure you want to publish these changes? They will be visible to all users.',
		variant: 'warning',
		confirmLabel: 'Yes, Publish',
		cancelLabel: 'Not Yet'
	}}
	{template}
/>
