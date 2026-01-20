<script>
	import Modal from './Modal.svelte';
	import Button from '../forms/Button.svelte';

	let {
		open = $bindable(false),
		title,
		message,
		confirmLabel = 'Confirm',
		cancelLabel = 'Cancel',
		variant = 'danger',
		onConfirm,
		onCancel
	} = $props();
</script>

<Modal bind:open {title}>
	<p class="text-gray-600 mb-6">{message}</p>
	<div class="flex justify-end space-x-3">
		<Button variant="secondary" autofocus onclick={onCancel}>
			{cancelLabel}
		</Button>
		<Button {variant} onclick={onConfirm}>
			{confirmLabel}
		</Button>
	</div>
</Modal>
