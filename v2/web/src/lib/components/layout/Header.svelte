<script>
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';

	let searchText = $state('');
	let mobileMenuOpen = $state(false);

	// Close mobile menu when route changes
	$effect(() => {
		$page.url;
		mobileMenuOpen = false;
	});

	function handleSearch(event) {
		event.preventDefault();
		if (searchText.trim()) {
			goto(`/globalsearch?q=${encodeURIComponent(searchText.trim())}`);
			searchText = '';
		}
	}

	function handleSearchKeydown(event) {
		if (event.key === 'Enter') {
			handleSearch(event);
		}
	}

	function toggleMobileMenu() {
		mobileMenuOpen = !mobileMenuOpen;
	}

	const navLinks = [
		{ href: '/id', label: 'Identify' },
		{ href: '/explore', label: 'Explore' }
	];

	const resourceLinks = [
		{ href: '/filterguide', label: 'Filter Terms' },
		{ href: '/glossary', label: 'Glossary' },
		{ href: '/refindex', label: 'Reference' }
	];
</script>

<header class="sticky top-0 z-50 bg-gf-maroon shadow-lg">
	<nav class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
		<div class="flex h-20 items-center justify-between">
			<!-- Logo -->
			<div class="flex-shrink-0">
				<a href="/" class="flex items-center">
					<img
						src="/branding/Wide Logo Versions/gallformers_logo_wide_color.png"
						alt="Gallformers logo: an oak gall wasp with a spherical oak gall and a white oak leaf"
						class="h-14"
					/>
				</a>
			</div>

			<!-- Desktop Navigation -->
			<div class="hidden md:flex md:items-center md:space-x-4">
				{#each navLinks as link}
					<a
						href={link.href}
						class="rounded-md px-3 py-2 text-sm font-medium text-white hover:bg-gf-maroon-dark hover:text-white transition-colors"
					>
						{link.label}
					</a>
				{/each}

				<!-- Search Form -->
				<form onsubmit={handleSearch} class="flex items-center">
					<input
						type="search"
						bind:value={searchText}
						onkeydown={handleSearchKeydown}
						placeholder="Search"
						aria-label="Search"
						class="w-40 rounded-l-md border-0 px-3 py-1.5 text-sm text-gray-900
						       placeholder:text-gray-400 focus:ring-2 focus:ring-white"
					/>
					<button
						type="submit"
						class="rounded-r-md border border-white bg-transparent px-3 py-1.5 text-sm
						       font-medium text-white hover:bg-white hover:text-gf-maroon transition-colors"
					>
						Search
					</button>
				</form>

				<!-- Resources Dropdown -->
				<div class="relative group">
					<button
						type="button"
						class="flex items-center rounded-md px-3 py-2 text-sm font-medium text-white
						       hover:bg-gf-maroon-dark transition-colors"
					>
						Resources
						<svg class="ml-1 h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
						</svg>
					</button>
					<div
						class="absolute right-0 z-10 mt-1 w-48 origin-top-right rounded-md bg-white py-1 shadow-lg
						       ring-1 ring-black ring-opacity-5 opacity-0 invisible group-hover:opacity-100
						       group-hover:visible transition-all duration-150"
					>
						{#each resourceLinks as link}
							<a
								href={link.href}
								class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
							>
								{link.label}
							</a>
						{/each}
					</div>
				</div>

				<!-- Login Link -->
				<a
					href="/login"
					class="rounded-md px-3 py-2 text-sm font-medium text-white hover:bg-gf-maroon-dark transition-colors"
				>
					Login
				</a>
			</div>

			<!-- Mobile menu button -->
			<div class="flex md:hidden">
				<button
					type="button"
					onclick={toggleMobileMenu}
					class="inline-flex items-center justify-center rounded-md p-2 text-white
					       hover:bg-gf-maroon-dark focus:outline-none focus:ring-2 focus:ring-white"
					aria-expanded={mobileMenuOpen}
					aria-controls="mobile-menu"
				>
					<span class="sr-only">Open main menu</span>
					{#if mobileMenuOpen}
						<!-- Close icon -->
						<svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
						</svg>
					{:else}
						<!-- Hamburger icon -->
						<svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
						</svg>
					{/if}
				</button>
			</div>
		</div>

		<!-- Mobile menu -->
		{#if mobileMenuOpen}
			<div class="md:hidden" id="mobile-menu">
				<div class="space-y-1 px-2 pb-3 pt-2">
					{#each navLinks as link}
						<a
							href={link.href}
							class="block rounded-md px-3 py-2 text-base font-medium text-white
							       hover:bg-gf-maroon-dark"
						>
							{link.label}
						</a>
					{/each}

					<!-- Mobile Search -->
					<form onsubmit={handleSearch} class="px-3 py-2">
						<div class="flex">
							<input
								type="search"
								bind:value={searchText}
								onkeydown={handleSearchKeydown}
								placeholder="Search"
								aria-label="Search"
								class="flex-1 rounded-l-md border-0 px-3 py-2 text-sm text-gray-900
								       placeholder:text-gray-400 focus:ring-2 focus:ring-white"
							/>
							<button
								type="submit"
								class="rounded-r-md border border-white bg-transparent px-3 py-2 text-sm
								       font-medium text-white hover:bg-white hover:text-gf-maroon"
							>
								Search
							</button>
						</div>
					</form>

					<!-- Mobile Resources -->
					<div class="border-t border-gf-maroon-light pt-2">
						<span class="block px-3 py-2 text-xs font-semibold uppercase tracking-wider text-gray-300">
							Resources
						</span>
						{#each resourceLinks as link}
							<a
								href={link.href}
								class="block rounded-md px-3 py-2 text-base font-medium text-white
								       hover:bg-gf-maroon-dark"
							>
								{link.label}
							</a>
						{/each}
					</div>

					<!-- Mobile Login -->
					<div class="border-t border-gf-maroon-light pt-2">
						<a
							href="/login"
							class="block rounded-md px-3 py-2 text-base font-medium text-white
							       hover:bg-gf-maroon-dark"
						>
							Login
						</a>
					</div>
				</div>
			</div>
		{/if}
	</nav>
</header>
