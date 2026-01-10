<script>
	/**
	 * TaxonomyBreadcrumb - Family → Genus → Species navigation
	 *
	 * Displays taxonomy hierarchy with links to each level.
	 * Supports optional description text for genus (shown in parentheses).
	 *
	 * @typedef {Object} TaxonomyItem
	 * @property {number} id - Taxonomy ID
	 * @property {string} name - Taxonomy name
	 * @property {string} [description] - Optional description
	 */

	let {
		family,
		genus,
		section,
		showFamily = true,
		showGenus = true,
		showSection = false
	} = $props();

	/**
	 * Format name with optional description in parentheses
	 */
	function formatWithDescription(name, description) {
		if (description) {
			return `${name} (${description})`;
		}
		return name;
	}
</script>

<div class="flex flex-wrap items-center gap-1 text-sm">
	{#if showFamily && family}
		<span class="font-semibold text-gray-600">Family:</span>
		<a href="/family/{family.id}" class="text-blue-600 hover:underline">
			{family.name}
		</a>
	{/if}

	{#if showFamily && family && ((showGenus && genus) || (showSection && section))}
		<span class="text-gray-400 mx-1">|</span>
	{/if}

	{#if showGenus && genus}
		<span class="font-semibold text-gray-600">Genus:</span>
		<a href="/genus/{genus.id}" class="text-blue-600 hover:underline">
			{formatWithDescription(genus.name, genus.description)}
		</a>
	{/if}

	{#if showGenus && genus && showSection && section}
		<span class="text-gray-400 mx-1">|</span>
	{/if}

	{#if showSection && section}
		<span class="font-semibold text-gray-600">Section:</span>
		<a href="/section/{section.id}" class="text-blue-600 hover:underline">
			{formatWithDescription(section.name, section.description)}
		</a>
	{/if}
</div>
