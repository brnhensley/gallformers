<script>
	/**
	 * ExternalLinks - Links to iNaturalist, BugGuide, Google Scholar, and BHL
	 *
	 * Displays external resource links for a species. Shows different behavior
	 * for described vs undescribed species:
	 * - Described: Shows all four external links
	 * - Undescribed: Shows only iNaturalist with Gallformers Code observation field
	 */

	let { name, undescribed = false } = $props();

	/**
	 * Parse species name to extract genus + species for external linking.
	 * Handles subspecies (Genus species subspecies) and sexual generation
	 * info (Genus species (sexgen)).
	 */
	function parseSpecies(species) {
		const parts = species.split(' ');
		return encodeURIComponent(`${parts[0]} ${parts[1]}`);
	}

	/**
	 * For undescribed species, extract just the gallformers code (second word)
	 */
	function parseUndescribed(species) {
		return encodeURIComponent(species.split(' ')[1]);
	}

	function iNatUrl(species, isUndescribed) {
		if (isUndescribed) {
			return `https://www.inaturalist.org/observations?verifiable=any&place_id=any&field:Gallformers%20Code=${parseUndescribed(species)}`;
		}
		return `https://www.inaturalist.org/search?q=${parseSpecies(species)}`;
	}

	function bugguideUrl(species) {
		return `https://bugguide.net/index.php?q=search&keys=${parseSpecies(species)}&search=Search`;
	}

	function gScholarUrl(species) {
		return `https://scholar.google.com/scholar?hl=en&q=${parseSpecies(species)}`;
	}

	function bhlUrl(species) {
		return `https://www.biodiversitylibrary.org/search?SearchTerm=${parseSpecies(species)}&SearchCat=M&return=ADV#/names`;
	}
</script>

{#if !undescribed}
	<!-- Described species - show all four links -->
	<div class="grid grid-cols-2 md:grid-cols-4 gap-4">
		<a
			href={iNatUrl(name, false)}
			target="_blank"
			rel="noreferrer"
			class="flex items-center justify-center p-2 rounded hover:bg-gray-100 transition-colors"
			aria-label="Search for more information about this species on iNaturalist"
		>
			<img src="/images/inatlogo-small.png" alt="iNaturalist" class="h-10" />
		</a>

		<a
			href={bugguideUrl(name)}
			target="_blank"
			rel="noreferrer"
			class="flex items-center justify-center p-2 rounded hover:bg-gray-100 transition-colors"
			aria-label="Search for more information about this species on BugGuide"
		>
			<img src="/images/bugguide-small.png" alt="BugGuide" class="h-10" />
		</a>

		<a
			href={gScholarUrl(name)}
			target="_blank"
			rel="noreferrer"
			class="flex items-center justify-center p-2 rounded hover:bg-gray-100 transition-colors"
			aria-label="Search for more information about this species on Google Scholar"
		>
			<img src="/images/gscholar-small.png" alt="Google Scholar" class="h-10" />
		</a>

		<a
			href={bhlUrl(name)}
			target="_blank"
			rel="noreferrer"
			class="flex items-center justify-center p-2 rounded hover:bg-gray-100 transition-colors"
			aria-label="Search for more information about this species at the Biodiversity Heritage Library"
		>
			<img src="/images/bhllogo.png" alt="Biodiversity Heritage Library" class="h-10" />
		</a>
	</div>
{:else}
	<!-- Undescribed species - show only iNaturalist with explanation -->
	<div class="flex flex-col md:flex-row items-start md:items-center gap-2">
		<p class="text-sm flex-1">
			Unless noted otherwise in the ID Notes, observations of this gall are collected in the
			Observation Field <em>Gallformers Code</em> with value <em>{parseUndescribed(name)}</em> on
			iNaturalist. You can view them here:
		</p>
		<a
			href={iNatUrl(name, true)}
			target="_blank"
			rel="noreferrer"
			class="flex items-center justify-center p-2 rounded hover:bg-gray-100 transition-colors shrink-0"
			aria-label="View observations of this gall on iNaturalist"
		>
			<img src="/images/inatlogo-small.png" alt="iNaturalist" class="h-10" />
		</a>
	</div>
{/if}
