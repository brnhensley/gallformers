import { describe, test, expect, vi, beforeEach, afterEach } from 'vitest'
import { mountHook } from '../test/hook_test_helper.js'
import AutoDismiss from './auto_dismiss.js'

describe('AutoDismiss', () => {
  beforeEach(() => { vi.useFakeTimers() })
  afterEach(() => { vi.useRealTimers() })

  test('pushes lv:clear-flash after delay', () => {
    const hook = mountHook(AutoDismiss, '<div data-dismiss-after="3000" data-flash-kind="info"></div>')
    hook.mounted()

    vi.advanceTimersByTime(3000)

    const events = hook.__pushed
    expect(events).toHaveLength(1)
    expect(events[0].event).toBe('lv:clear-flash')
    expect(events[0].payload).toEqual({ key: 'info' })
  })

  test('hides element after delay', () => {
    const hook = mountHook(AutoDismiss, '<div data-dismiss-after="1000" data-flash-kind="error"></div>')
    hook.mounted()

    vi.advanceTimersByTime(1000)

    expect(hook.el.classList.contains('hidden')).toBe(true)
  })

  test('defaults to 5000ms delay', () => {
    const hook = mountHook(AutoDismiss, '<div data-flash-kind="info"></div>')
    hook.mounted()

    vi.advanceTimersByTime(4999)
    expect(hook.__pushed).toHaveLength(0)

    vi.advanceTimersByTime(1)
    expect(hook.__pushed).toHaveLength(1)
  })

  test('destroyed clears timer', () => {
    const hook = mountHook(AutoDismiss, '<div data-dismiss-after="1000" data-flash-kind="info"></div>')
    hook.mounted()
    hook.destroyed()

    vi.advanceTimersByTime(2000)

    expect(hook.__pushed).toHaveLength(0)
  })
})
