import { describe, test, expect, beforeEach } from 'vitest'
import { mountHook } from '../test/hook_test_helper.js'
import RegionPrompt from './region_prompt.js'

function promptHTML() {
  return `
    <div class="hidden">
      <button data-prompt-code="XN">North America</button>
      <button data-prompt-code="XE">Europe</button>
      <button data-prompt-code="">All Regions</button>
    </div>
  `
}

describe('RegionPrompt', () => {
  beforeEach(() => {
    localStorage.clear()
  })

  test('shows when no continent and not dismissed', () => {
    const hook = mountHook(RegionPrompt, promptHTML())
    hook.mounted()

    expect(hook.el.classList.contains('hidden')).toBe(false)
  })

  test('stays hidden when continent is set', () => {
    localStorage.setItem('gf_continent', 'XN')

    const hook = mountHook(RegionPrompt, promptHTML())
    hook.mounted()

    expect(hook.el.classList.contains('hidden')).toBe(true)
  })

  test('stays hidden when dismissed', () => {
    localStorage.setItem('gf_continent_dismissed', 'true')

    const hook = mountHook(RegionPrompt, promptHTML())
    hook.mounted()

    expect(hook.el.classList.contains('hidden')).toBe(true)
  })

  test('clicking a region code sets localStorage and hides', () => {
    const hook = mountHook(RegionPrompt, promptHTML())
    hook.mounted()

    hook.el.querySelector('[data-prompt-code="XN"]').click()

    expect(localStorage.getItem('gf_continent')).toBe('XN')
    expect(localStorage.getItem('gf_continent_dismissed')).toBe('true')
    expect(hook.el.classList.contains('hidden')).toBe(true)
  })

  test('clicking empty code just dismisses without setting continent', () => {
    const hook = mountHook(RegionPrompt, promptHTML())
    hook.mounted()

    hook.el.querySelector('[data-prompt-code=""]').click()

    expect(localStorage.getItem('gf_continent')).toBeNull()
    expect(localStorage.getItem('gf_continent_dismissed')).toBe('true')
    expect(hook.el.classList.contains('hidden')).toBe(true)
  })
})
