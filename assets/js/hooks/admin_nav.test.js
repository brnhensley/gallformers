import { describe, test, expect, vi } from 'vitest'
import { mountHook } from '../test/hook_test_helper.js'
import AdminNav from './admin_nav.js'

function navHTML() {
  return `
    <nav>
      <a data-nav-href="/admin">Dashboard</a>
      <a data-nav-href="/admin/galls">Galls</a>
      <a data-nav-href="/admin/hosts">Hosts</a>
    </nav>
  `
}

function getLink(hook, href) {
  return hook.el.querySelector(`[data-nav-href="${href}"]`)
}

describe('AdminNav', () => {
  test('highlights exact match for /admin', () => {
    vi.stubGlobal('location', { pathname: '/admin' })

    const hook = mountHook(AdminNav, navHTML())
    hook.mounted()

    expect(getLink(hook, '/admin').classList.contains('underline')).toBe(true)
    expect(getLink(hook, '/admin/galls').classList.contains('opacity-50')).toBe(true)

    vi.unstubAllGlobals()
  })

  test('highlights prefix match for sub-paths', () => {
    vi.stubGlobal('location', { pathname: '/admin/galls/123' })

    const hook = mountHook(AdminNav, navHTML())
    hook.mounted()

    expect(getLink(hook, '/admin/galls').classList.contains('underline')).toBe(true)
    expect(getLink(hook, '/admin').classList.contains('opacity-50')).toBe(true)
    expect(getLink(hook, '/admin/hosts').classList.contains('opacity-50')).toBe(true)

    vi.unstubAllGlobals()
  })

  test('updated re-highlights', () => {
    vi.stubGlobal('location', { pathname: '/admin/hosts' })

    const hook = mountHook(AdminNav, navHTML())
    hook.mounted()

    expect(getLink(hook, '/admin/hosts').classList.contains('underline')).toBe(true)

    // Simulate navigation
    vi.stubGlobal('location', { pathname: '/admin/galls' })
    hook.updated()

    expect(getLink(hook, '/admin/galls').classList.contains('underline')).toBe(true)
    expect(getLink(hook, '/admin/hosts').classList.contains('opacity-50')).toBe(true)

    vi.unstubAllGlobals()
  })
})
