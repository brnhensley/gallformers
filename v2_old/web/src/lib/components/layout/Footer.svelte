<script>
	const currentYear = new Date().getFullYear();

	let menuOpen = $state(false);

	function toggleMenu() {
		menuOpen = !menuOpen;
	}

	// Close menu when clicking a link
	function closeMenu() {
		menuOpen = false;
	}
</script>

<footer class="fixed bottom-0 left-0 right-0 z-40 bg-gray-100 text-gf-maroon">
	<div class="flex items-center justify-between px-4 py-2">
		<!-- Login - left side (desktop only, in mobile menu otherwise) -->
		<a
			href="/login"
			class="hidden sm:block text-base font-medium !text-gf-maroon hover:underline"
		>
			Login
		</a>

		<!-- Copyright - center -->
		<span class="hidden sm:block text-sm text-gray-600">
			&copy; {currentYear} Gallformers |
			<a
				href="https://creativecommons.org/licenses/by-nc-sa/4.0/"
				target="_blank"
				rel="noopener noreferrer"
				class="!text-gf-maroon hover:underline"
			>
				CC BY-NC-SA 4.0
			</a>
		</span>

		<!-- Navigation Links - right side (desktop) -->
		<nav
			class="hidden sm:flex items-center gap-x-4"
			aria-label="Footer navigation"
		>
			<a
				href="https://megachile.shinyapps.io/doycalc/"
				target="_blank"
				rel="noopener noreferrer"
				class="text-base font-medium !text-gf-maroon hover:underline"
			>
				Phenology Tool
			</a>
			<a
				href="https://www.patreon.com/gallformers"
				target="_blank"
				rel="noopener noreferrer"
				class="text-base font-medium !text-gf-maroon hover:underline"
			>
				Donate
			</a>
			<a
				href="/about"
				class="text-base font-medium !text-gf-maroon hover:underline"
			>
				About
			</a>
		</nav>

		<!-- Mobile menu - collapsible -->
		<nav
			class="{menuOpen ? 'flex flex-col absolute bottom-full left-0 right-0 bg-gray-100 py-3 border-t border-gray-300' : 'hidden'} sm:hidden"
			aria-label="Footer navigation mobile"
		>
			<a
				href="/login"
				class="text-base font-medium !text-gf-maroon hover:underline py-1 px-4"
				onclick={closeMenu}
			>
				Login
			</a>
			<a
				href="https://megachile.shinyapps.io/doycalc/"
				target="_blank"
				rel="noopener noreferrer"
				class="text-base font-medium !text-gf-maroon hover:underline py-1 px-4"
				onclick={closeMenu}
			>
				Phenology Tool
			</a>
			<a
				href="https://www.patreon.com/gallformers"
				target="_blank"
				rel="noopener noreferrer"
				class="text-base font-medium !text-gf-maroon hover:underline py-1 px-4"
				onclick={closeMenu}
			>
				Donate
			</a>
			<a
				href="/about"
				class="text-base font-medium !text-gf-maroon hover:underline py-1 px-4"
				onclick={closeMenu}
			>
				About
			</a>
			<!-- Copyright in mobile menu -->
			<span class="text-sm text-gray-600 py-1 px-4 mt-2 border-t border-gray-300 pt-2">
				&copy; {currentYear} Gallformers |
				<a
					href="https://creativecommons.org/licenses/by-nc-sa/4.0/"
					target="_blank"
					rel="noopener noreferrer"
					class="!text-gf-maroon hover:underline"
					onclick={closeMenu}
				>
					CC BY-NC-SA 4.0
				</a>
			</span>
		</nav>

		<!-- Hamburger button - visible only on mobile -->
		<button
			type="button"
			class="sm:hidden p-2 text-gf-maroon ml-auto"
			onclick={toggleMenu}
			aria-label="Toggle footer menu"
			aria-expanded={menuOpen}
		>
			<svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
				{#if menuOpen}
					<!-- X icon when open -->
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
				{:else}
					<!-- Hamburger icon when closed -->
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
				{/if}
			</svg>
		</button>
	</div>
</footer>
