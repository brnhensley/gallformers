import { describe, test, expect, vi, beforeEach } from 'vitest'
import { mountHook } from '../test/hook_test_helper.js'
import RegionScope from './region_scope.js'

function scopeHTML() {
  return `
    <div>
      <button data-region-toggle>Toggle</button>
      <div data-region-dropdown class="hidden">
        <button data-region-code="XN" class="font-bold">North America</button>
        <button data-region-code="XE">Europe</button>
        <button data-region-save>Set as default</button>
      </div>
    </div>
  `
}

describe('RegionScope', () => {
  beforeEach(() => {
    localStorage.clear()
  })

  test('toggle click shows dropdown', () => {
    const hook = mountHook(RegionScope, scopeHTML())
    hook.mounted()

    hook.el.querySelector('[data-region-toggle]').click()

    expect(hook.el.querySelector('[data-region-dropdown]').classList.contains('hidden')).toBe(false)
  })

  test('toggle click again hides dropdown', () => {
    const hook = mountHook(RegionScope, scopeHTML())
    hook.mounted()

    const toggle = hook.el.querySelector('[data-region-toggle]')
    toggle.click()
    toggle.click()

    expect(hook.el.querySelector('[data-region-dropdown]').classList.contains('hidden')).toBe(true)
  })

  test('click-away closes dropdown', () => {
    const hook = mountHook(RegionScope, scopeHTML())
    hook.mounted()

    // Open dropdown
    hook.el.querySelector('[data-region-toggle]').click()

    // Click outside
    document.body.click()

    expect(hook.el.querySelector('[data-region-dropdown]').classList.contains('hidden')).toBe(true)
  })

  test('save button with active region sets localStorage', () => {
    // Stub reload to prevent jsdom error
    const reloadMock = vi.fn()
    vi.stubGlobal('location', { ...window.location, reload: reloadMock })

    const hook = mountHook(RegionScope, scopeHTML())
    hook.mounted()

    hook.el.querySelector('[data-region-save]').click()

    expect(localStorage.getItem('gf_continent')).toBe('XN')
    expect(localStorage.getItem('gf_continent_dismissed')).toBe('true')

    vi.unstubAllGlobals()
  })

  test('save button with no active region removes continent from localStorage', () => {
    localStorage.setItem('gf_continent', 'XN')
    const reloadMock = vi.fn()
    vi.stubGlobal('location', { ...window.location, reload: reloadMock })

    // No font-bold on any region button = no active region
    const html = `
      <div>
        <button data-region-toggle>Toggle</button>
        <div data-region-dropdown class="hidden">
          <button data-region-code="XN">North America</button>
          <button data-region-save>Set as default</button>
        </div>
      </div>
    `
    const hook = mountHook(RegionScope, html)
    hook.mounted()

    hook.el.querySelector('[data-region-save]').click()

    expect(localStorage.getItem('gf_continent')).toBeNull()

    vi.unstubAllGlobals()
  })
})
