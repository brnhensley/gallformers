<script lang="ts">
	import type { Snippet } from 'svelte';

	let {
		open = $bindable(false),
		title,
		children
	}: {
		open?: boolean;
		title: string;
		children: Snippet;
	} = $props();

	let dialogEl: HTMLDialogElement;

	$effect(() => {
		if (open) {
			dialogEl?.showModal();
		} else {
			dialogEl?.close();
		}
	});

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') {
			open = false;
		}
	}

	function handleBackdropClick(e: MouseEvent) {
		if (e.target === dialogEl) {
			open = false;
		}
	}
</script>

<dialog
	bind:this={dialogEl}
	onkeydown={handleKeydown}
	onclick={handleBackdropClick}
	class="rounded-lg shadow-xl max-w-lg w-full p-0 backdrop:bg-black/50"
>
	<div class="p-6">
		<h2 class="text-lg font-semibold text-gray-900 mb-4">{title}</h2>
		{@render children?.()}
	</div>
</dialog>
