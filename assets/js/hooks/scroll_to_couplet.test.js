import { describe, test, expect, vi, beforeEach } from 'vitest'
import { mountHook, pushServerEvent, getPushedEvents } from '../test/hook_test_helper.js'
import ScrollToCouplet from './scroll_to_couplet.js'

describe('ScrollToCouplet', () => {
  beforeEach(() => {
    // Stub browser APIs
    vi.stubGlobal('requestAnimationFrame', (cb) => cb())
    vi.stubGlobal('scrollTo', vi.fn())

    // Stub navigator.clipboard
    Object.assign(navigator, {
      clipboard: { writeText: vi.fn(() => Promise.resolve()) }
    })
  })

  test('scroll_to_couplet scrolls to the element by ID', () => {
    const target = document.createElement('div')
    target.id = 'couplet-5'
    document.body.appendChild(target)

    const hook = mountHook(ScrollToCouplet, '<div></div>')
    hook.mounted()

    pushServerEvent(hook, 'scroll_to_couplet', { id: 'couplet-5' })

    expect(window.scrollTo).toHaveBeenCalled()

    target.remove()
  })

  test('scroll_to_couplet does nothing for missing element', () => {
    const hook = mountHook(ScrollToCouplet, '<div></div>')
    hook.mounted()

    pushServerEvent(hook, 'scroll_to_couplet', { id: 'nonexistent' })

    expect(window.scrollTo).not.toHaveBeenCalled()
  })

  test('copy_to_clipboard replaces {{KEY_URL}} template', async () => {
    const hook = mountHook(ScrollToCouplet, '<div></div>')
    hook.mounted()

    pushServerEvent(hook, 'copy_to_clipboard', {
      text: 'Check this key: {{KEY_URL}}',
      url_path: '/keys/1'
    })

    await vi.waitFor(() =>
      expect(navigator.clipboard.writeText).toHaveBeenCalledWith(
        `Check this key: ${window.location.origin}/keys/1`
      )
    )
  })

  test('copy_to_clipboard replaces {{KEY_URL_ORIGIN}} template', async () => {
    const hook = mountHook(ScrollToCouplet, '<div></div>')
    hook.mounted()

    pushServerEvent(hook, 'copy_to_clipboard', {
      text: 'Visit {{KEY_URL_ORIGIN}} for more'
    })

    await vi.waitFor(() =>
      expect(navigator.clipboard.writeText).toHaveBeenCalledWith(
        `Visit ${window.location.origin} for more`
      )
    )
  })

  test('copy success pushes clipboard_copy_success event', async () => {
    const hook = mountHook(ScrollToCouplet, '<div></div>')
    hook.mounted()

    pushServerEvent(hook, 'copy_to_clipboard', { text: 'test' })

    await vi.waitFor(() =>
      expect(getPushedEvents(hook).some(e => e.event === 'clipboard_copy_success')).toBe(true)
    )
  })
})
