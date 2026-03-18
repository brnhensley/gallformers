import { describe, test, expect } from 'vitest'
import { mountHook, getPushedEvents } from '../test/hook_test_helper.js'
import InputEvent from './input_event.js'

describe('InputEvent', () => {
  test('input event pushes configured event with value', () => {
    const hook = mountHook(InputEvent, '<input data-event="update_name" value="Quercus" />')
    hook.mounted()

    hook.el.value = 'Quercus alba'
    hook.el.dispatchEvent(new Event('input', { bubbles: true }))

    const events = getPushedEvents(hook)
    expect(events).toHaveLength(1)
    expect(events[0].event).toBe('update_name')
    expect(events[0].payload).toEqual({ value: 'Quercus alba' })
  })

  test('with target pushes to component', () => {
    const hook = mountHook(InputEvent, '<input data-event="update_name" data-target="42" />')
    hook.mounted()

    hook.el.value = 'test'
    hook.el.dispatchEvent(new Event('input', { bubbles: true }))

    const events = getPushedEvents(hook)
    expect(events[0].selector).toBe('[data-phx-component="42"]')
  })

  test('without target pushes to LiveView', () => {
    const hook = mountHook(InputEvent, '<input data-event="update_name" />')
    hook.mounted()

    hook.el.value = 'test'
    hook.el.dispatchEvent(new Event('input', { bubbles: true }))

    const events = getPushedEvents(hook)
    expect(events[0].selector).toBeUndefined()
  })

  test('no data-event does nothing', () => {
    const hook = mountHook(InputEvent, '<input />')
    hook.mounted()

    hook.el.dispatchEvent(new Event('input', { bubbles: true }))

    expect(getPushedEvents(hook)).toHaveLength(0)
  })
})
