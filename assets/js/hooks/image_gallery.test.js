import { describe, test, expect, beforeEach } from 'vitest'
import { mountHook, getPushedEvents } from '../test/hook_test_helper.js'
import ImageGallery from './image_gallery.js'

const TEST_IMAGES = [
  {
    src: '/img/gall1.jpg',
    alt: 'Oak apple gall',
    caption: 'On Quercus alba',
    creator: 'J. Smith',
    license: 'CC BY 4.0',
    licenselink: 'https://creativecommons.org/licenses/by/4.0/',
    sourcelink: 'https://example.com/1',
    source_title: 'iNaturalist',
    attribution: 'Photo by J. Smith',
    uploader: 'admin',
    lastchangedby: 'admin'
  },
  {
    src: '/img/gall2.jpg',
    alt: 'Cynipid gall',
    caption: '',
    creator: 'A. Jones',
    license: 'Public domain',
    licenselink: '',
    sourcelink: '',
    source_title: ''
  },
  {
    src: '/img/gall3.jpg',
    alt: 'Leaf gall',
    caption: 'Close-up view'
  }
]

function galleryHTML(images = TEST_IMAGES) {
  return `
    <div data-images='${JSON.stringify(images)}' tabindex="0">
      <img data-main-image src="" alt="" />
      <span data-counter></span>
      <span data-caption></span>
      <button data-prev>Prev</button>
      <button data-next>Next</button>
      <button data-open-lightbox>Expand</button>
      <button data-open-info>Info</button>

      <a data-source-link href="#"><span>Source</span></a>
      <span data-creator></span>
      <a data-license-link href="#"><span data-license></span></a>
      <span data-license-nolink></span>
      <span data-license-tooltip></span>

      <dialog data-lightbox>
        <img data-lightbox-image src="" alt="" />
        <a data-lightbox-source-link href="#"></a>
        <span data-lightbox-creator></span>
        <a data-lightbox-license-link href="#"><span data-lightbox-license></span></a>
        <span data-lightbox-license-nolink></span>
        <button data-close-lightbox>Close</button>
      </dialog>

      <dialog data-info-dialog>
        <img data-info-image src="" />
        <a data-info-source href="#"></a>
        <a data-info-license-link href="#"></a>
        <span data-info-license-nolink></span>
        <span data-info-attribution></span>
        <span data-info-creator></span>
        <span data-info-uploader></span>
        <span data-info-lastchangedby></span>
        <span data-info-caption></span>
        <button data-close-info>Close</button>
      </dialog>
    </div>
  `
}

function keydown(element, key) {
  element.dispatchEvent(new KeyboardEvent('keydown', { key, bubbles: true, cancelable: true }))
}

// Stub dialog methods (jsdom doesn't implement HTMLDialogElement fully)
function stubDialogs(hook) {
  hook.el.querySelectorAll('dialog').forEach(d => {
    d.showModal = d.showModal || function () { this.open = true }
    d.close = d.close || function () { this.open = false }
  })
}

describe('ImageGallery navigation', () => {
  let hook

  beforeEach(() => {
    hook = mountHook(ImageGallery, galleryHTML())
    stubDialogs(hook)
    hook.mounted()
  })

  test('starts at index 0', () => {
    expect(hook.currentIndex).toBe(0)
  })

  test('next advances index', () => {
    hook.el.querySelector('[data-next]').click()

    expect(hook.currentIndex).toBe(1)
  })

  test('prev from 0 wraps to last', () => {
    hook.el.querySelector('[data-prev]').click()

    expect(hook.currentIndex).toBe(2)
  })

  test('next wraps from last to 0', () => {
    hook.el.querySelector('[data-next]').click()
    hook.el.querySelector('[data-next]').click()
    hook.el.querySelector('[data-next]').click()

    expect(hook.currentIndex).toBe(0)
  })

  test('ArrowRight advances', () => {
    keydown(hook.el, 'ArrowRight')

    expect(hook.currentIndex).toBe(1)
  })

  test('ArrowLeft goes back', () => {
    keydown(hook.el, 'ArrowRight')
    keydown(hook.el, 'ArrowLeft')

    expect(hook.currentIndex).toBe(0)
  })
})

describe('ImageGallery display update', () => {
  let hook

  beforeEach(() => {
    hook = mountHook(ImageGallery, galleryHTML())
    stubDialogs(hook)
    hook.mounted()
    // Navigate to first image to trigger initial display
    hook.updateDisplay()
  })

  test('updates main image src and alt', () => {
    expect(hook.el.querySelector('[data-main-image]').src).toContain('/img/gall1.jpg')
    expect(hook.el.querySelector('[data-main-image]').alt).toBe('Oak apple gall')
  })

  test('updates counter', () => {
    expect(hook.el.querySelector('[data-counter]').textContent).toBe('1 / 3')
  })

  test('shows caption when present', () => {
    expect(hook.el.querySelector('[data-caption]').textContent).toBe('On Quercus alba')
    expect(hook.el.querySelector('[data-caption]').classList.contains('hidden')).toBe(false)
  })

  test('hides caption when empty', () => {
    hook.el.querySelector('[data-next]').click() // image 2 has empty caption

    expect(hook.el.querySelector('[data-caption]').classList.contains('hidden')).toBe(true)
  })

  test('updates creator', () => {
    expect(hook.el.querySelector('[data-creator]').textContent).toBe('J. Smith')
  })

  test('shows license link when licenselink present', () => {
    const link = hook.el.querySelector('[data-license-link]')
    expect(link.href).toContain('creativecommons.org')
    expect(link.classList.contains('hidden')).toBe(false)

    const noLink = hook.el.querySelector('[data-license-nolink]')
    expect(noLink.classList.contains('hidden')).toBe(true)
  })

  test('shows license text without link when licenselink empty', () => {
    hook.el.querySelector('[data-next]').click() // image 2 has no licenselink

    const link = hook.el.querySelector('[data-license-link]')
    expect(link.classList.contains('hidden')).toBe(true)

    const noLink = hook.el.querySelector('[data-license-nolink]')
    expect(noLink.classList.contains('hidden')).toBe(false)
    expect(noLink.textContent).toBe('Public domain')
  })

  test('pushes gallery_index_changed event', () => {
    const events = getPushedEvents(hook)
    expect(events.some(e => e.event === 'gallery_index_changed' && e.payload.index === 0)).toBe(true)
  })

  test('navigation pushes new index', () => {
    hook.el.querySelector('[data-next]').click()

    const events = getPushedEvents(hook)
    expect(events.some(e => e.event === 'gallery_index_changed' && e.payload.index === 1)).toBe(true)
  })
})

describe('ImageGallery lightbox', () => {
  let hook

  beforeEach(() => {
    hook = mountHook(ImageGallery, galleryHTML())
    stubDialogs(hook)
    hook.mounted()
  })

  test('open lightbox sets state and shows dialog', () => {
    hook.el.querySelector('[data-open-lightbox]').click()

    expect(hook.lightboxOpen).toBe(true)
    expect(hook.el.querySelector('[data-lightbox]').open).toBe(true)
  })

  test('close lightbox clears state and closes dialog', () => {
    hook.el.querySelector('[data-open-lightbox]').click()
    hook.el.querySelector('[data-close-lightbox]').click()

    expect(hook.lightboxOpen).toBe(false)
    expect(hook.el.querySelector('[data-lightbox]').open).toBe(false)
  })

  test('Escape closes lightbox', () => {
    hook.el.querySelector('[data-open-lightbox]').click()
    keydown(hook.el, 'Escape')

    expect(hook.lightboxOpen).toBe(false)
  })
})

describe('ImageGallery info dialog', () => {
  let hook

  beforeEach(() => {
    hook = mountHook(ImageGallery, galleryHTML())
    stubDialogs(hook)
    hook.mounted()
  })

  test('open info sets state and shows dialog', () => {
    hook.el.querySelector('[data-open-info]').click()

    expect(hook.infoOpen).toBe(true)
    expect(hook.el.querySelector('[data-info-dialog]').open).toBe(true)
  })

  test('close info clears state', () => {
    hook.el.querySelector('[data-open-info]').click()
    hook.el.querySelector('[data-close-info]').click()

    expect(hook.infoOpen).toBe(false)
  })

  test('Escape closes info', () => {
    hook.el.querySelector('[data-open-info]').click()
    keydown(hook.el, 'Escape')

    expect(hook.infoOpen).toBe(false)
  })

  test('info dialog shows attribution fields', () => {
    hook.updateDisplay()

    expect(hook.el.querySelector('[data-info-attribution]').textContent).toBe('Photo by J. Smith')
    expect(hook.el.querySelector('[data-info-creator]').textContent).toBe('J. Smith')
    expect(hook.el.querySelector('[data-info-uploader]').textContent).toBe('admin')
  })
})

describe('ImageGallery edge cases', () => {
  test('single image gallery does not crash on navigation', () => {
    const hook = mountHook(ImageGallery, galleryHTML([{ src: '/img/only.jpg', alt: 'Only' }]))
    stubDialogs(hook)
    hook.mounted()

    hook.el.querySelector('[data-next]').click()
    expect(hook.currentIndex).toBe(0) // wraps back

    hook.el.querySelector('[data-prev]').click()
    expect(hook.currentIndex).toBe(0) // wraps back
  })

  test('empty images array does not crash', () => {
    const hook = mountHook(ImageGallery, galleryHTML([]))
    stubDialogs(hook)
    hook.mounted()

    // Should not throw
    hook.el.querySelector('[data-next]').click()
    hook.el.querySelector('[data-prev]').click()
  })
})
