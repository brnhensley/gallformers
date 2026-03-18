/**
 * Minimal LiveView hook test helper.
 *
 * Creates a fake hook context that simulates what LiveView provides at runtime:
 * this.el, this.pushEvent, this.pushEventTo, this.handleEvent.
 *
 * Usage:
 *   const hook = mountHook(IndeterminateCheckbox, '<input type="checkbox" data-indeterminate="true" />')
 *   hook.mounted()
 *   expect(hook.el.indeterminate).toBe(true)
 */

/**
 * Mount a hook with a given HTML string as the element.
 * Returns the hook instance with the LiveView context mixed in.
 */
export function mountHook(hookDef, html) {
  const el = createElementFromHTML(html)
  document.body.appendChild(el)

  const pushed = []
  const eventHandlers = {}

  const context = {
    el,
    pushEvent(event, payload) { pushed.push({ event, payload }) },
    pushEventTo(selector, event, payload) { pushed.push({ selector, event, payload }) },
    handleEvent(name, callback) { eventHandlers[name] = callback },

    // Test inspection
    __pushed: pushed,
    __eventHandlers: eventHandlers,
  }

  // Create the hook instance: prototype chain from the hook definition,
  // with the LiveView context properties mixed in.
  const hook = Object.create(hookDef)
  Object.assign(hook, context)

  return hook
}

/**
 * Simulate a server push event arriving at the hook.
 * Only works if the hook registered a handler via this.handleEvent().
 */
export function pushServerEvent(hook, name, payload) {
  const handler = hook.__eventHandlers[name]
  if (!handler) throw new Error(`No handler registered for event "${name}"`)
  handler(payload)
}

/**
 * Get all events the hook has pushed to the server.
 */
export function getPushedEvents(hook) {
  return hook.__pushed
}

/**
 * Stub browser APIs that jsdom doesn't implement.
 * These are external browser APIs, not our code — stubbing them is correct.
 */
if (typeof Element.prototype.scrollIntoView !== 'function') {
  Element.prototype.scrollIntoView = function () {}
}

function createElementFromHTML(html) {
  const div = document.createElement('div')
  div.innerHTML = html.trim()
  return div.firstChild
}
