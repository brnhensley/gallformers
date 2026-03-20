import { describe, test, expect } from 'vitest'
import { mountHook } from '../test/hook_test_helper.js'
import IndeterminateCheckbox from './indeterminate_checkbox.js'

describe('IndeterminateCheckbox', () => {
  test('mounted sets indeterminate when data attribute is "true"', () => {
    const hook = mountHook(IndeterminateCheckbox, '<input type="checkbox" data-indeterminate="true" />')
    hook.mounted()

    expect(hook.el.indeterminate).toBe(true)
  })

  test('mounted does not set indeterminate when data attribute is "false"', () => {
    const hook = mountHook(IndeterminateCheckbox, '<input type="checkbox" data-indeterminate="false" />')
    hook.mounted()

    expect(hook.el.indeterminate).toBe(false)
  })

  test('mounted does not set indeterminate when data attribute is missing', () => {
    const hook = mountHook(IndeterminateCheckbox, '<input type="checkbox" />')
    hook.mounted()

    expect(hook.el.indeterminate).toBe(false)
  })

  test('updated reflects changed data attribute', () => {
    const hook = mountHook(IndeterminateCheckbox, '<input type="checkbox" data-indeterminate="false" />')
    hook.mounted()
    expect(hook.el.indeterminate).toBe(false)

    // Simulate LiveView updating the data attribute
    hook.el.dataset.indeterminate = 'true'
    hook.updated()

    expect(hook.el.indeterminate).toBe(true)
  })

  test('updated clears indeterminate when attribute changes to false', () => {
    const hook = mountHook(IndeterminateCheckbox, '<input type="checkbox" data-indeterminate="true" />')
    hook.mounted()
    expect(hook.el.indeterminate).toBe(true)

    hook.el.dataset.indeterminate = 'false'
    hook.updated()

    expect(hook.el.indeterminate).toBe(false)
  })
})
