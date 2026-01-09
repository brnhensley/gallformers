<script>
	import ConfirmModal from './ConfirmModal.svelte';
	import Button from '../forms/Button.svelte';

	let {
		buttonLabel = 'Open',
		buttonVariant = 'primary',
		title = 'Confirm',
		message = 'Are you sure?',
		variant = 'danger',
		confirmLabel = 'Confirm',
		cancelLabel = 'Cancel'
	} = $props();

	let open = $state(false);
</script>

<Button variant={buttonVariant} onclick={() => (open = true)}>{buttonLabel}</Button>
<ConfirmModal
	bind:open
	{title}
	{message}
	{variant}
	{confirmLabel}
	{cancelLabel}
	onConfirm={() => {
		console.log('Confirmed!');
		open = false;
	}}
	onCancel={() => (open = false)}
/>
