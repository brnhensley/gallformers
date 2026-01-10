<script>
	/**
	 * EditButton - Admin edit link, hidden for public users
	 *
	 * Renders an edit link to the admin page for a given entity.
	 * Only visible when the user is authenticated (passed via prop).
	 * Hidden entirely for public/unauthenticated users.
	 *
	 * @typedef {'taxonomy' | 'gall' | 'gallhost' | 'glossary' | 'host' | 'images' | 'source' | 'speciessource' | 'section' | 'place'} EntityType
	 */

	let { id, type, isAuthenticated = false, label = '' } = $props();

	// Build admin URL
	let href = $derived(`/admin/${type}?id=${id}`);
</script>

{#if isAuthenticated}
	<a
		{href}
		class="inline-flex items-center gap-1 p-1 text-gray-500 hover:text-gf-maroon rounded
               transition-colors focus:outline-none focus:ring-2 focus:ring-offset-1 focus:ring-gf-maroon"
		title="Edit {type}"
		aria-label="Edit this {type}"
	>
		<svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
			<path
				stroke-linecap="round"
				stroke-linejoin="round"
				stroke-width="2"
				d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
			/>
		</svg>
		{#if label}
			<span class="text-sm">{label}</span>
		{/if}
	</a>
{/if}
