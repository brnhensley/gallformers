/**
 * ArticleImageUpload Hook
 *
 * Handles single image upload for articles with:
 * - File type validation
 * - Direct upload to S3 using presigned URLs
 * - Inserts HTML figure/img at cursor position in content textarea
 */

const ArticleImageUpload = {
  mounted() {
    this.acceptedTypes = ["image/jpeg", "image/png", "image/jpg"]
    this.contentTextareaId = this.el.dataset.contentTextarea

    this.fileInput = this.el.querySelector("[data-file-input]")
    this.uploadButton = this.el.querySelector("[data-upload-trigger]")
    this.statusEl = this.el.querySelector("[data-status]")

    this.setupEventListeners()
  },

  setupEventListeners() {
    if (this.uploadButton) {
      this.uploadButton.addEventListener("click", () => this.fileInput?.click())
    }

    if (this.fileInput) {
      this.fileInput.addEventListener("change", (e) => this.handleFileSelect(e))
    }

    // Listen for presigned URL response
    this.handleEvent("article_presigned_url", ({ url, path, content_type, image_url }) => {
      this.executeUpload(url, path, content_type, image_url)
    })

    // Listen for upload error
    this.handleEvent("article_upload_error", ({ message }) => {
      this.showStatus(message, "error")
    })

    // Listen for image selection from browser (inserting existing image)
    this.handleEvent("insert_image_markdown", ({ markdown }) => {
      this.insertMarkdownAtCursor(markdown)
    })
  },

  handleFileSelect(e) {
    const file = e.target.files[0]
    if (!file) return

    // Reset input
    e.target.value = ""

    // Validate type
    if (!this.acceptedTypes.includes(file.type)) {
      this.showStatus("Only JPG and PNG images are supported", "error")
      return
    }

    // Validate size (5MB max)
    if (file.size > 5 * 1024 * 1024) {
      this.showStatus("Image must be under 5MB", "error")
      return
    }

    this.currentFile = file
    this.showStatus("Preparing upload...", "info")

    // Request presigned URL
    this.pushEvent("request_article_image_url", {
      name: file.name,
      type: file.type,
      extension: file.name.split(".").pop()
    })
  },

  async executeUpload(presignedUrl, path, contentType, imageUrl) {
    if (!this.currentFile) return

    this.showStatus("Uploading...", "info")

    try {
      const response = await fetch(presignedUrl, {
        method: "PUT",
        body: this.currentFile,
        headers: {
          "Content-Type": contentType
        }
      })

      if (response.ok) {
        // Notify server of successful upload
        this.pushEvent("article_image_uploaded", { path })
        this.showStatus("Upload complete!", "success")

        // Insert markdown at cursor position in content textarea
        this.insertMarkdownIntoTextarea(imageUrl)
      } else {
        this.showStatus(`Upload failed: HTTP ${response.status}`, "error")
      }
    } catch (error) {
      this.showStatus(`Upload failed: ${error.message}`, "error")
    }

    this.currentFile = null
  },

  insertMarkdownIntoTextarea(imageUrl) {
    // Generate HTML matching the Browse Images format with placeholders
    const html = `<figure>
  <img src="${imageUrl}" alt="[Describe the image]" width="400">
  <figcaption>[Add caption]</figcaption>
</figure>`
    this.insertMarkdownAtCursor(html)
  },

  insertMarkdownAtCursor(markdown) {
    const textarea = document.getElementById(this.contentTextareaId)
    if (!textarea) return

    // Insert at cursor position or append to end
    const start = textarea.selectionStart
    const end = textarea.selectionEnd
    const before = textarea.value.substring(0, start)
    const after = textarea.value.substring(end)

    // Add newlines for clean insertion
    const prefix = before.length > 0 && !before.endsWith("\n") ? "\n" : ""
    const suffix = after.length > 0 && !after.startsWith("\n") ? "\n" : ""

    textarea.value = before + prefix + markdown + suffix + after

    // Trigger input event so LiveView picks up the change
    textarea.dispatchEvent(new Event("input", { bubbles: true }))

    // Move cursor after the inserted markdown
    const newPosition = start + prefix.length + markdown.length + suffix.length
    textarea.setSelectionRange(newPosition, newPosition)
    textarea.focus()
  },

  showStatus(message, type) {
    if (!this.statusEl) return

    this.statusEl.textContent = message
    this.statusEl.className = "text-sm mt-2 " + {
      info: "text-gray-600",
      success: "text-green-600",
      error: "text-red-600"
    }[type]

    // Clear success/error messages after 5 seconds
    if (type !== "info") {
      setTimeout(() => {
        if (this.statusEl.textContent === message) {
          this.statusEl.textContent = ""
        }
      }, 5000)
    }
  }
}

export default ArticleImageUpload
