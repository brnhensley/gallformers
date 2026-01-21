/**
 * SortableImages Hook
 *
 * Enables drag-and-drop reordering of images in a grid.
 * The first image in the order becomes the default image.
 */

const SortableImages = {
  mounted() {
    this.container = this.el
    this.draggingEl = null
    this.placeholder = null

    this.setupDragListeners()
  },

  updated() {
    // Re-setup listeners when the DOM updates
    this.setupDragListeners()
  },

  setupDragListeners() {
    const items = this.container.querySelectorAll("[data-image-id]")

    items.forEach(item => {
      // Make items draggable
      item.setAttribute("draggable", "true")

      item.addEventListener("dragstart", (e) => this.handleDragStart(e, item))
      item.addEventListener("dragend", (e) => this.handleDragEnd(e))
      item.addEventListener("dragover", (e) => this.handleDragOver(e, item))
      item.addEventListener("drop", (e) => this.handleDrop(e, item))
    })
  },

  handleDragStart(e, item) {
    this.draggingEl = item
    item.classList.add("opacity-50", "ring-2", "ring-gf-maroon")

    // Set drag data
    e.dataTransfer.effectAllowed = "move"
    e.dataTransfer.setData("text/plain", item.dataset.imageId)

    // Create placeholder
    this.placeholder = document.createElement("div")
    this.placeholder.className = "w-24 h-24 border-2 border-dashed border-gf-maroon rounded bg-gf-sky-blue/20"
  },

  handleDragEnd(e) {
    if (this.draggingEl) {
      this.draggingEl.classList.remove("opacity-50", "ring-2", "ring-gf-maroon")
      this.draggingEl = null
    }

    if (this.placeholder && this.placeholder.parentNode) {
      this.placeholder.remove()
    }
    this.placeholder = null
  },

  handleDragOver(e, item) {
    e.preventDefault()
    e.dataTransfer.dropEffect = "move"

    if (item === this.draggingEl) return

    // Get bounding rect to determine drop position
    const rect = item.getBoundingClientRect()
    const midpoint = rect.left + rect.width / 2

    // Insert placeholder before or after based on mouse position
    if (e.clientX < midpoint) {
      item.parentNode.insertBefore(this.placeholder, item)
    } else {
      item.parentNode.insertBefore(this.placeholder, item.nextSibling)
    }
  },

  handleDrop(e, item) {
    e.preventDefault()

    if (!this.draggingEl || this.draggingEl === item) return

    // Move the dragged element to the placeholder position
    if (this.placeholder && this.placeholder.parentNode) {
      this.placeholder.parentNode.insertBefore(this.draggingEl, this.placeholder)
      this.placeholder.remove()
    }

    // Get new order and send to server
    const newOrder = Array.from(this.container.querySelectorAll("[data-image-id]"))
      .map(el => parseInt(el.dataset.imageId, 10))

    this.pushEvent("reorder_images", { order: newOrder })
  }
}

export default SortableImages
