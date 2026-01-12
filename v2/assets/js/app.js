// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

// Import external hooks
import RangeMap from "./hooks/range_map"

// Custom hooks for UI components
const Tabs = {
  mounted() {
    const defaultTab = this.el.dataset.defaultTab
    this.activateTab(defaultTab)

    // Handle tab clicks
    this.el.querySelectorAll("[data-tab-id]").forEach(button => {
      button.addEventListener("click", (e) => {
        this.activateTab(e.currentTarget.dataset.tabId)
      })
    })

    // Handle keyboard navigation
    this.el.querySelectorAll("[data-tab-id]").forEach(button => {
      button.addEventListener("keydown", (e) => {
        const tabs = Array.from(this.el.querySelectorAll("[data-tab-id]"))
        const currentIndex = tabs.indexOf(e.currentTarget)
        let newIndex = currentIndex

        if (e.key === "ArrowLeft") {
          newIndex = currentIndex > 0 ? currentIndex - 1 : tabs.length - 1
        } else if (e.key === "ArrowRight") {
          newIndex = currentIndex < tabs.length - 1 ? currentIndex + 1 : 0
        } else if (e.key === "Home") {
          newIndex = 0
        } else if (e.key === "End") {
          newIndex = tabs.length - 1
        } else {
          return
        }

        e.preventDefault()
        const newTab = tabs[newIndex]
        newTab.focus()
        this.activateTab(newTab.dataset.tabId)
      })
    })
  },
  activateTab(tabId) {
    // Update tab buttons
    this.el.querySelectorAll("[data-tab-id]").forEach(button => {
      if (button.dataset.tabId === tabId) {
        button.setAttribute("data-active", "")
        button.setAttribute("aria-selected", "true")
      } else {
        button.removeAttribute("data-active")
        button.setAttribute("aria-selected", "false")
      }
    })

    // Update tab panels
    this.el.querySelectorAll("[data-tab-panel]").forEach(panel => {
      if (panel.dataset.tabPanel === tabId) {
        panel.setAttribute("data-active", "")
      } else {
        panel.removeAttribute("data-active")
      }
    })
  }
}

// ImageGallery hook for keyboard navigation and lightbox
const ImageGallery = {
  mounted() {
    this.currentIndex = 0
    this.images = JSON.parse(this.el.dataset.images || "[]")
    this.lightboxOpen = false

    // Keyboard navigation
    this.keyHandler = (e) => {
      if (e.key === "ArrowLeft") {
        this.prevImage()
      } else if (e.key === "ArrowRight") {
        this.nextImage()
      } else if (e.key === "Escape" && this.lightboxOpen) {
        this.closeLightbox()
      }
    }

    this.el.addEventListener("keydown", this.keyHandler)

    // Navigation button handlers
    this.el.querySelectorAll("[data-prev]").forEach(btn => {
      btn.addEventListener("click", () => this.prevImage())
    })
    this.el.querySelectorAll("[data-next]").forEach(btn => {
      btn.addEventListener("click", () => this.nextImage())
    })

    // Lightbox handlers
    this.el.querySelectorAll("[data-open-lightbox]").forEach(btn => {
      btn.addEventListener("click", () => this.openLightbox())
    })
    this.el.querySelectorAll("[data-close-lightbox]").forEach(btn => {
      btn.addEventListener("click", () => this.closeLightbox())
    })
  },
  destroyed() {
    this.el.removeEventListener("keydown", this.keyHandler)
  },
  prevImage() {
    this.currentIndex = this.currentIndex > 0 ? this.currentIndex - 1 : this.images.length - 1
    this.updateDisplay()
  },
  nextImage() {
    this.currentIndex = this.currentIndex < this.images.length - 1 ? this.currentIndex + 1 : 0
    this.updateDisplay()
  },
  updateDisplay() {
    // Update main image
    const mainImg = this.el.querySelector("[data-main-image]")
    if (mainImg && this.images[this.currentIndex]) {
      mainImg.src = this.images[this.currentIndex].src
      mainImg.alt = this.images[this.currentIndex].alt || ""
    }

    // Update lightbox image
    const lightboxImg = this.el.querySelector("[data-lightbox-image]")
    if (lightboxImg && this.images[this.currentIndex]) {
      lightboxImg.src = this.images[this.currentIndex].src
      lightboxImg.alt = this.images[this.currentIndex].alt || ""
    }

    // Update counter
    const counter = this.el.querySelector("[data-counter]")
    if (counter) {
      counter.textContent = `${this.currentIndex + 1} / ${this.images.length}`
    }

    // Push event to server if needed
    this.pushEvent("gallery_index_changed", {index: this.currentIndex})
  },
  openLightbox() {
    this.lightboxOpen = true
    const lightbox = this.el.querySelector("[data-lightbox]")
    if (lightbox) {
      lightbox.showModal()
    }
  },
  closeLightbox() {
    this.lightboxOpen = false
    const lightbox = this.el.querySelector("[data-lightbox]")
    if (lightbox) {
      lightbox.close()
    }
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {Tabs, ImageGallery, RangeMap},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

