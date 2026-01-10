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
	let dialogEl;

	// Current image helper
	let currentImage = $derived(images.length > 0 ? images[currentIndex] : null);
	let hasImages = $derived(images.length > 0);
	let hasPrev = $derived(currentIndex > 0);
	let hasNext = $derived(currentIndex < images.length - 1);

	function goToPrev() {
		if (hasPrev) {
			currentIndex--;
			notifyChange();
		}
	}

	function goToNext() {
		if (hasNext) {
			currentIndex++;
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

	$effect(() => {
		if (lightboxOpen) {
			dialogEl?.showModal();
		} else {
			dialogEl?.close();
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

			<!-- Navigation Arrows -->
			{#if images.length > 1}
				<button
					type="button"
					onclick={goToPrev}
					disabled={!hasPrev}
					class="absolute left-2 top-1/2 -translate-y-1/2 bg-black/50 hover:bg-black/70 text-white rounded-full w-10 h-10 flex items-center justify-center disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
					aria-label="Previous image"
				>
					<svg class="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
					</svg>
				</button>
				<button
					type="button"
					onclick={goToNext}
					disabled={!hasNext}
					class="absolute right-2 top-1/2 -translate-y-1/2 bg-black/50 hover:bg-black/70 text-white rounded-full w-10 h-10 flex items-center justify-center disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
					aria-label="Next image"
				>
					<svg class="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
					</svg>
				</button>
			{/if}
		</div>

		<!-- Caption & Attribution -->
		<div class="p-3 bg-white border-t">
			{#if currentImage.caption}
				<p class="text-sm text-gray-700 mb-2">{currentImage.caption}</p>
			{/if}

			<div class="text-xs text-gray-500 flex flex-wrap items-center gap-1">
				{#if currentImage.sourceLink}
					<a
						href={currentImage.sourceLink}
						target="_blank"
						rel="noreferrer"
						class="text-blue-600 hover:underline"
					>
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
						<a
							href={currentImage.licenseLink}
							target="_blank"
							rel="noreferrer"
							class="text-blue-600 hover:underline"
						>
							{currentImage.license}
						</a>
					{:else}
						<span>{currentImage.license}</span>
					{/if}
				{/if}
			</div>
		</div>

		<!-- Dot Indicators -->
		{#if images.length > 1}
			<div class="flex justify-center gap-2 py-2 bg-white border-t">
				{#each images as _, index}
					<button
						type="button"
						onclick={() => goToIndex(index)}
						class="w-2 h-2 rounded-full transition-colors {index === currentIndex
							? 'bg-blue-600'
							: 'bg-gray-300 hover:bg-gray-400'}"
						aria-label="Go to image {index + 1}"
					></button>
				{/each}
			</div>
		{/if}
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
						disabled={!hasPrev}
						class="absolute left-4 bg-white/20 hover:bg-white/40 text-white rounded-full w-12 h-12 flex items-center justify-center disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
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
						disabled={!hasNext}
						class="absolute right-4 bg-white/20 hover:bg-white/40 text-white rounded-full w-12 h-12 flex items-center justify-center disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
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
