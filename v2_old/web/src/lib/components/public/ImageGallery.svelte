<script>
	/**
	 * ImageGallery - Carousel with attribution, lightbox, and placeholder fallback
	 *
	 * @typedef {Object} GalleryImage
	 * @property {number} id - Image ID
	 * @property {string} url - Image URL
	 * @property {string} alt - Alt text
	 * @property {string} [caption] - Optional caption
	 * @property {string} [creator] - Image creator/photographer
	 * @property {string} [license] - License type (e.g., "CC BY", "Public Domain")
	 * @property {string} [licenseLink] - URL to license
	 * @property {string} [sourceLink] - URL to original source
	 */

	let {
		images = [],
		placeholderSrc = '/images/noimage.jpg',
		placeholderAlt = 'No image available',
		onimagechange
	} = $props();

	let currentIndex = $state(0);
	let lightboxOpen = $state(false);
	let infoModalOpen = $state(false);
	let showCopyrightTooltip = $state(false);
	let dialogEl;
	let infoDialogEl;

	// Current image helper
	let currentImage = $derived(images.length > 0 ? images[currentIndex] : null);
	let hasImages = $derived(images.length > 0);

	function goToPrev() {
		if (images.length > 1) {
			// Wrap around to end if at beginning
			currentIndex = currentIndex > 0 ? currentIndex - 1 : images.length - 1;
			notifyChange();
		}
	}

	function goToNext() {
		if (images.length > 1) {
			// Wrap around to beginning if at end
			currentIndex = currentIndex < images.length - 1 ? currentIndex + 1 : 0;
			notifyChange();
		}
	}

	function goToIndex(index) {
		if (index >= 0 && index < images.length) {
			currentIndex = index;
			notifyChange();
		}
	}

	function notifyChange() {
		if (onimagechange && currentImage) {
			onimagechange(currentIndex, currentImage);
		}
	}

	function openLightbox() {
		lightboxOpen = true;
	}

	function closeLightbox() {
		lightboxOpen = false;
	}

	function openInfoModal() {
		infoModalOpen = true;
	}

	function closeInfoModal() {
		infoModalOpen = false;
	}

	function handleKeydown(e) {
		if (e.key === 'Escape') {
			closeLightbox();
		} else if (e.key === 'ArrowLeft') {
			goToPrev();
		} else if (e.key === 'ArrowRight') {
			goToNext();
		}
	}

	function handleBackdropClick(e) {
		if (e.target === dialogEl) {
			closeLightbox();
		}
	}

	function handleInfoBackdropClick(e) {
		if (e.target === infoDialogEl) {
			closeInfoModal();
		}
	}

	$effect(() => {
		if (lightboxOpen) {
			dialogEl?.showModal();
		} else {
			dialogEl?.close();
		}
	});

	$effect(() => {
		if (infoModalOpen) {
			infoDialogEl?.showModal();
		} else {
			infoDialogEl?.close();
		}
	});
</script>

<div class="relative bg-gray-100 rounded-lg overflow-hidden">
	{#if hasImages}
		<!-- Main Image -->
		<div class="relative aspect-[4/3] flex items-center justify-center bg-gray-50">
			<button
				type="button"
				onclick={openLightbox}
				class="w-full h-full flex items-center justify-center cursor-zoom-in focus:outline-none focus:ring-2 focus:ring-blue-500"
				aria-label="Open image in lightbox"
			>
				<img
					src={currentImage.url}
					alt={currentImage.alt}
					class="max-w-full max-h-full object-contain"
				/>
			</button>

			<!-- Navigation Arrows (overlapping image, edge-to-edge) -->
			{#if images.length > 1}
				<button
					type="button"
					onclick={goToPrev}
					class="absolute left-0 top-1/2 -translate-y-1/2 bg-black/40 hover:bg-black/60 text-white w-10 h-16 flex items-center justify-center transition-colors"
					aria-label="Previous image"
				>
					<svg class="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
					</svg>
				</button>
				<button
					type="button"
					onclick={goToNext}
					class="absolute right-0 top-1/2 -translate-y-1/2 bg-black/40 hover:bg-black/60 text-white w-10 h-16 flex items-center justify-center transition-colors"
					aria-label="Next image"
				>
					<svg class="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
					</svg>
				</button>
			{/if}
		</div>

		<!-- Button Bar (like V1: copyright, info) -->
		<div class="flex justify-center gap-1 py-2 bg-white border-t">
			<!-- Copyright/License button with tooltip -->
			<div class="relative">
				<button
					type="button"
					onclick={() => (showCopyrightTooltip = !showCopyrightTooltip)}
					onblur={() => (showCopyrightTooltip = false)}
					class="px-3 py-1 text-lg bg-gray-200 hover:bg-gray-300 rounded transition-colors"
					aria-label="Show license information"
				>
					©
				</button>
				{#if showCopyrightTooltip && currentImage?.license}
					<div class="absolute bottom-full left-1/2 -translate-x-1/2 mb-2 px-3 py-2 bg-gray-800 text-white text-sm rounded shadow-lg whitespace-nowrap z-10">
						{currentImage.license}
						<div class="absolute top-full left-1/2 -translate-x-1/2 border-4 border-transparent border-t-gray-800"></div>
					</div>
				{/if}
			</div>

			<!-- Info button -->
			<button
				type="button"
				onclick={openInfoModal}
				class="px-3 py-1 text-lg font-bold bg-gray-200 hover:bg-gray-300 rounded transition-colors"
				aria-label="Show image details"
			>
				ⓘ
			</button>
		</div>
	{:else}
		<!-- Placeholder for no images -->
		<div class="aspect-[4/3] flex items-center justify-center bg-gray-200">
			<img src={placeholderSrc} alt={placeholderAlt} class="max-w-full max-h-full object-contain opacity-60" />
		</div>
		<div class="p-3 bg-white border-t">
			<p class="text-sm text-gray-500 text-center">No images available</p>
		</div>
	{/if}
</div>

<!-- Lightbox Modal -->
<dialog
	bind:this={dialogEl}
	onkeydown={handleKeydown}
	onclick={handleBackdropClick}
	class="p-0 bg-transparent max-w-none w-screen h-screen backdrop:bg-black/90"
>
	{#if currentImage}
		<div class="w-full h-full flex flex-col items-center justify-center p-4">
			<!-- Close button -->
			<button
				type="button"
				onclick={closeLightbox}
				class="absolute top-4 right-4 text-white hover:text-gray-300 z-10"
				aria-label="Close lightbox"
			>
				<svg class="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
				</svg>
			</button>

			<!-- Image container -->
			<div class="relative flex-1 flex items-center justify-center w-full">
				{#if images.length > 1}
					<button
						type="button"
						onclick={goToPrev}
						class="absolute left-4 bg-white/20 hover:bg-white/40 text-white rounded-full w-12 h-12 flex items-center justify-center transition-colors"
						aria-label="Previous image"
					>
						<svg class="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
						</svg>
					</button>
				{/if}

				<img
					src={currentImage.url}
					alt={currentImage.alt}
					class="max-w-full max-h-[85vh] object-contain"
				/>

				{#if images.length > 1}
					<button
						type="button"
						onclick={goToNext}
						class="absolute right-4 bg-white/20 hover:bg-white/40 text-white rounded-full w-12 h-12 flex items-center justify-center transition-colors"
						aria-label="Next image"
					>
						<svg class="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
						</svg>
					</button>
				{/if}
			</div>

			<!-- Caption & Attribution in lightbox -->
			<div class="text-center text-white mt-4 max-w-2xl">
				{#if currentImage.caption}
					<p class="text-sm mb-2">{currentImage.caption}</p>
				{/if}
				<div class="text-xs text-gray-300 flex flex-wrap justify-center items-center gap-1">
					{#if currentImage.sourceLink}
						<a href={currentImage.sourceLink} target="_blank" rel="noreferrer" class="text-blue-300 hover:underline">
							Image
						</a>
					{:else}
						<span>Image</span>
					{/if}
					{#if currentImage.creator}
						<span>by {currentImage.creator}</span>
					{/if}
					{#if currentImage.license}
						<span class="mx-1">©</span>
						{#if currentImage.licenseLink}
							<a href={currentImage.licenseLink} target="_blank" rel="noreferrer" class="text-blue-300 hover:underline">
								{currentImage.license}
							</a>
						{:else}
							<span>{currentImage.license}</span>
						{/if}
					{/if}
				</div>
				{#if images.length > 1}
					<p class="text-xs text-gray-400 mt-2">{currentIndex + 1} / {images.length}</p>
				{/if}
			</div>
		</div>
	{/if}
</dialog>

<!-- Info Modal -->
<dialog
	bind:this={infoDialogEl}
	onclick={handleInfoBackdropClick}
	class="p-0 bg-transparent max-w-2xl backdrop:bg-black/50 rounded-lg"
>
	{#if currentImage}
		<div class="bg-white rounded-lg shadow-xl">
			<!-- Header -->
			<div class="flex items-center justify-between px-4 py-3 border-b">
				<h3 class="text-lg font-semibold">Image Details</h3>
				<button
					type="button"
					onclick={closeInfoModal}
					class="text-gray-500 hover:text-gray-700"
					aria-label="Close"
				>
					<svg class="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
					</svg>
				</button>
			</div>

			<!-- Body -->
			<div class="p-4 flex gap-4">
				<!-- Thumbnail -->
				<div class="flex-shrink-0 w-32">
					<img
						src={currentImage.url}
						alt={currentImage.alt}
						class="w-full h-auto rounded border"
					/>
				</div>

				<!-- Details -->
				<div class="flex-1 space-y-2 text-sm">
					{#if currentImage.sourceLink}
						<div>
							<strong>Source:</strong>{' '}
							<a href={currentImage.sourceLink} target="_blank" rel="noreferrer" class="text-blue-600 hover:underline">
								{currentImage.sourceLink}
							</a>
						</div>
					{/if}
					{#if currentImage.license}
						<div>
							<strong>License:</strong>{' '}
							{#if currentImage.licenseLink}
								<a href={currentImage.licenseLink} target="_blank" rel="noreferrer" class="text-blue-600 hover:underline">
									{currentImage.license}
								</a>
							{:else}
								{currentImage.license}
							{/if}
						</div>
					{/if}
					{#if currentImage.creator}
						<div>
							<strong>Creator:</strong> {currentImage.creator}
						</div>
					{/if}
					{#if currentImage.caption}
						<div>
							<strong>Caption:</strong> {currentImage.caption}
						</div>
					{/if}
				</div>
			</div>
		</div>
	{/if}
</dialog>
