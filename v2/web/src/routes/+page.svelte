<script>
	import { onMount } from 'svelte';

	let randomGall = $state(null);
	let loading = $state(true);
	let error = $state(null);

	onMount(async () => {
		try {
			// Fetch a random gall from the API
			const response = await fetch('/api/v2/galls?limit=1&offset=' + Math.floor(Math.random() * 100));
			if (!response.ok) throw new Error('Failed to fetch random gall');
			const data = await response.json();
			if (data.data && data.data.length > 0) {
				randomGall = data.data[0];
			}
		} catch (err) {
			error = err.message;
		} finally {
			loading = false;
		}
	});
</script>

<svelte:head>
	<title>Gallformers - Plant Gall Identification</title>
	<meta name="description" content="The place to identify and learn about galls on plants in the US and Canada." />
</svelte:head>

<div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
	<!-- Hero Section -->
	<div class="text-center mb-8">
		<h1 class="text-3xl font-bold text-gf-maroon mb-2">Welcome to Gallformers</h1>
		<p class="text-lg text-gf-autumn">
			The place to identify and learn about galls on plants in the US and Canada.
		</p>
	</div>

	<div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
		<!-- What is a Gall -->
		<div class="bg-white rounded border border-gray-200 shadow-sm">
			<div class="px-4 py-3 border-b border-gray-200">
				<h2 class="text-xl font-semibold text-gf-maroon">What the heck is a gall?!</h2>
			</div>
			<div class="p-4">
				<p class="text-gray-700 leading-relaxed description-text">
					Plant galls are abnormal growths of plant tissues, similar to tumors or warts in animals,
					that have an external cause--such as an insect, mite, nematode, virus, fungus, bacterium,
					or even another plant species. Growths caused by genetic mutations are not galls. Nor are
					lerps and other constructions on a plant that do not contain plant tissue. Plant galls are
					often complex structures that allow the insect or mite that caused the gall to be identified
					even if that insect or mite is not visible.
				</p>
			</div>
		</div>

		<!-- Stuff You Can Do -->
		<div class="bg-white rounded border border-gray-200 shadow-sm">
			<div class="px-4 py-3 border-b border-gray-200">
				<h2 class="text-xl font-semibold text-gf-maroon">Stuff you can do.</h2>
			</div>
			<div class="p-4">
				<ul class="space-y-2">
					<li>
						<a href="/id" class="text-gf-maroon hover:underline font-medium">
							Identify Galls
						</a>
					</li>
					<li>
						<a href="/refindex" class="text-gf-maroon hover:underline font-medium">
							Learn More About Galls
						</a>
					</li>
					<li>
						<a href="/explore" class="text-gf-maroon hover:underline font-medium">
							Explore the Data
						</a>
					</li>
					<li>
						<a
							href="https://megachile.shinyapps.io/doycalc/"
							target="_blank"
							rel="noreferrer"
							class="text-gf-maroon hover:underline font-medium"
						>
							Explore the seasonal timing of gall development and emergence with our phenology tool
						</a>
					</li>
				</ul>
			</div>
		</div>
	</div>

	<!-- Random Gall and Help Section -->
	<div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mt-6">
		<!-- Random Gall -->
		<div class="bg-white rounded border border-gray-200 shadow-sm">
			{#if loading}
				<div class="p-6 text-center">
					<div class="animate-spin rounded-full h-12 w-12 border-b-2 border-gf-maroon mx-auto"></div>
					<p class="mt-4 text-gray-600">Loading random gall...</p>
				</div>
			{:else if error}
				<div class="p-6 text-center text-red-600">
					<p>Could not load random gall: {error}</p>
				</div>
			{:else if randomGall}
				<div class="flex items-center justify-center h-48 bg-gray-50">
					<a href="/gall/{randomGall.id}" class="block">
						<img
							src="/images/cynipid_R.svg"
							alt="Gall wasp illustration"
							class="h-32 w-auto opacity-50"
						/>
					</a>
				</div>
				<div class="p-4">
					<p class="text-gray-700">
						Here is a random gall from our database.
						{#if randomGall.undescribed}
							This one is an undescribed species called{' '}
						{:else}
							This one is called{' '}
						{/if}
						<a href="/gall/{randomGall.id}" class="text-gf-maroon hover:underline">
							<em>{randomGall.name}</em>
						</a>.
					</p>
				</div>
			{:else}
				<div class="p-6 text-center text-gray-600">
					<p>No galls found in the database.</p>
				</div>
			{/if}
		</div>

		<!-- Help Us Out -->
		<div class="bg-white rounded border border-gray-200 shadow-sm">
			<div class="px-4 py-3 border-b border-gray-200">
				<h2 class="text-xl font-semibold text-gf-maroon">Help Us Out</h2>
			</div>
			<div class="p-4">
				<p class="text-gray-700 mb-4">
					If you find gallformers.org useful and you are interested in helping us out there are a few
					ways you can do so:
				</p>
				<ul class="space-y-2">
					<li>
						<a
							href="https://www.patreon.com/gallformers"
							target="_blank"
							rel="noreferrer"
							class="text-gf-maroon hover:underline font-medium"
						>
							Help cover operational costs via donations to our Patreon
						</a>
					</li>
					<li>
						<a href="/about#administrators" class="text-gf-maroon hover:underline font-medium">
							Help add and maintain our data as an Administrator
						</a>
					</li>
					<li>
						<a
							href="https://github.com/jeffdc/gallformers"
							target="_blank"
							rel="noreferrer"
							class="text-gf-maroon hover:underline font-medium"
						>
							Help fix bugs and add new features
						</a>
					</li>
				</ul>
			</div>
		</div>
	</div>
</div>
