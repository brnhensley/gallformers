import { describe, test, expect } from 'vitest'
import { mountHook, getPushedEvents, pushServerEvent } from '../test/hook_test_helper.js'
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

  test('Enter pushes the configured enter-event with current value', () => {
    const hook = mountHook(InputEvent, '<input data-event="update_name" data-enter-event="add_thing" />')
    hook.mounted()

    hook.el.value = 'Quercus'
    hook.el.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true, cancelable: true }))

    const events = getPushedEvents(hook)
    expect(events).toHaveLength(1)
    expect(events[0].event).toBe('add_thing')
    expect(events[0].payload).toEqual({ value: 'Quercus' })
  })

  test('Enter prevents default to avoid submitting surrounding form', () => {
    const hook = mountHook(InputEvent, '<input data-enter-event="add_thing" />')
    hook.mounted()

    const ev = new KeyboardEvent('keydown', { key: 'Enter', bubbles: true, cancelable: true })
    hook.el.dispatchEvent(ev)

    expect(ev.defaultPrevented).toBe(true)
  })

  test('Enter without data-enter-event does nothing', () => {
    const hook = mountHook(InputEvent, '<input data-event="update_name" />')
    hook.mounted()

    hook.el.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }))

    expect(getPushedEvents(hook)).toHaveLength(0)
  })

  test('non-Enter keys do not push the enter-event', () => {
    const hook = mountHook(InputEvent, '<input data-enter-event="add_thing" />')
    hook.mounted()

    hook.el.dispatchEvent(new KeyboardEvent('keydown', { key: 'a', bubbles: true }))

    expect(getPushedEvents(hook)).toHaveLength(0)
  })

  test('clear_input server event clears value when id matches', () => {
    const hook = mountHook(InputEvent, '<input id="my-input" value="hello" />')
    hook.mounted()
    hook.el.value = 'typed text'

    pushServerEvent(hook, 'clear_input', { id: 'my-input' })

    expect(hook.el.value).toBe('')
  })

  test('clear_input server event ignores other input ids', () => {
    const hook = mountHook(InputEvent, '<input id="my-input" value="hello" />')
    hook.mounted()
    hook.el.value = 'typed text'

    pushServerEvent(hook, 'clear_input', { id: 'other-input' })

    expect(hook.el.value).toBe('typed text')
  })
})
