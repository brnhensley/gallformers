import { describe, test, expect, vi, beforeEach } from 'vitest'
import { mountHook, getPushedEvents } from '../test/hook_test_helper.js'
import CopyToClipboard from './copy_to_clipboard.js'

describe('CopyToClipboard', () => {
  beforeEach(() => {
    // Stub navigator.clipboard
    Object.assign(navigator, {
      clipboard: { writeText: vi.fn(() => Promise.resolve()) }
    })
  })

  test('click copies data-copy-text to clipboard', async () => {
    const hook = mountHook(CopyToClipboard, '<button data-copy-text="hello world"></button>')
    hook.mounted()

    hook.el.click()
    await vi.waitFor(() => expect(navigator.clipboard.writeText).toHaveBeenCalledWith('hello world'))
  })

  test('with data-copy-url prepends origin', async () => {
    const hook = mountHook(CopyToClipboard, '<button data-copy-text="/gall/123" data-copy-url></button>')
    hook.mounted()

    hook.el.click()
    await vi.waitFor(() =>
      expect(navigator.clipboard.writeText).toHaveBeenCalledWith(`${window.location.origin}/gall/123`)
    )
  })

  test('success pushes clipboard_copy_success event', async () => {
    const hook = mountHook(CopyToClipboard, '<button data-copy-text="test"></button>')
    hook.mounted()

    hook.el.click()
    await vi.waitFor(() => expect(getPushedEvents(hook).some(e => e.event === 'clipboard_copy_success')).toBe(true))
  })

  test('failure pushes clipboard_copy_error event', async () => {
    navigator.clipboard.writeText = vi.fn(() => Promise.reject(new Error('denied')))

    const hook = mountHook(CopyToClipboard, '<button data-copy-text="test"></button>')
    hook.mounted()

    hook.el.click()
    await vi.waitFor(() => expect(getPushedEvents(hook).some(e => e.event === 'clipboard_copy_error')).toBe(true))
  })

  test('click with no data-copy-text does nothing', () => {
    const hook = mountHook(CopyToClipboard, '<button></button>')
    hook.mounted()

    hook.el.click()

    expect(navigator.clipboard.writeText).not.toHaveBeenCalled()
  })
})
