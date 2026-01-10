<script>
	const currentYear = new Date().getFullYear();

	const footerLinks = [
		{ href: '/about', label: 'About' },
	];

	const socialLinks = [
		{
			href: 'https://github.com/jeffdc/gallformers',
			label: 'GitHub',
			icon: 'github'
		},
		{
			href: 'https://www.patreon.com/gallformers',
			label: 'Support on Patreon',
			icon: 'patreon'
		}
	];
</script>

<footer class="bg-gray-100 text-gf-maroon">
	<div class="mx-auto px-4 py-6 sm:px-6 lg:px-8">
		<div class="md:flex md:items-center md:justify-between">
			<!-- Footer Navigation -->
			<nav class="flex flex-wrap justify-center gap-x-6 md:justify-start" aria-label="Footer navigation">
				{#each footerLinks as link}
					<a
						href={link.href}
						class="text-base font-medium text-gf-maroon hover:underline transition-colors"
					>
						{link.label}
					</a>
				{/each}
			</nav>

			<!-- Social Links -->
			<div class="mt-4 flex justify-center space-x-6 md:mt-0">
				{#each socialLinks as social}
					<a
						href={social.href}
						target="_blank"
						rel="noopener noreferrer"
						class="text-gf-maroon hover:text-gf-autumn transition-colors"
						aria-label={social.label}
					>
						{#if social.icon === 'github'}
							<svg class="h-6 w-6" fill="currentColor" viewBox="0 0 24 24">
								<path
									fill-rule="evenodd"
									d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z"
									clip-rule="evenodd"
								/>
							</svg>
						{:else if social.icon === 'patreon'}
							<svg class="h-6 w-6" fill="currentColor" viewBox="0 0 24 24">
								<path
									d="M15.386 2c-3.848 0-6.97 3.121-6.97 6.97 0 3.848 3.122 6.969 6.97 6.969 3.849 0 6.97-3.121 6.97-6.97 0-3.848-3.121-6.969-6.97-6.969zM1.644 22h3.229V2H1.644v20z"
								/>
							</svg>
						{/if}
					</a>
				{/each}
			</div>
		</div>

		<!-- Copyright and License -->
		<div class="mt-4 border-t border-gray-300 pt-4">
			<p class="text-center text-xs text-gray-600">
				&copy; {currentYear} Gallformers.
			</p>
			<p class="mt-1 text-center text-xs text-gray-500">
				Content is available under
				<a
					href="https://creativecommons.org/licenses/by-nc-sa/4.0/"
					target="_blank"
					rel="noopener noreferrer"
					class="text-gf-maroon hover:underline"
				>
					CC BY-NC-SA 4.0
				</a>
				unless otherwise noted.
			</p>
		</div>
	</div>
</footer>
