<script>
	import { page } from '$app/stores';
</script>

<svelte:head>
	<title>{$page.status} - Gallformers</title>
	<meta name="description" content="Page not found - Gallformers" />
</svelte:head>

<div class="min-h-[60vh] flex items-center justify-center px-4">
	<div class="text-center bg-white p-8 rounded-lg shadow-lg max-w-lg">
		<div class="text-6xl font-bold text-gf-maroon mb-4">
			{$page.status}
		</div>

		{#if $page.status === 404}
			<h1 class="text-2xl font-semibold text-gray-800 mb-4">
				This Page Was Not Found
			</h1>
			<p class="text-gray-600 mb-6">
				Notably this is also not a gall, though it sure does look like one.
			</p>
			<div class="mb-6">
				<a href="https://www.inaturalist.org/observations/58767231" target="_blank" rel="noreferrer">
					<img
						src="/images/scale.jpg"
						alt="A scale insect not a gall"
						class="max-w-full h-auto rounded-lg mx-auto shadow-md"
						onerror={(e) => { e.target.style.display = 'none' }}
					/>
				</a>
			</div>
		{:else}
			<h1 class="text-2xl font-semibold text-gray-800 mb-4">
				Something went wrong
			</h1>
			<p class="text-gray-600 mb-6">
				{$page.error?.message || 'An unexpected error occurred.'}
			</p>
		{/if}

		<div class="flex flex-col sm:flex-row gap-4 justify-center">
			<a
				href="/"
				class="inline-block px-6 py-3 bg-gf-maroon text-white font-medium rounded-lg hover:bg-gf-maroon-dark transition-colors"
			>
				Go back home
			</a>
			<a
				href="/id"
				class="inline-block px-6 py-3 border border-gf-maroon text-gf-maroon font-medium rounded-lg hover:bg-gray-50 transition-colors"
			>
				Try our ID tool
			</a>
		</div>
	</div>
</div>
