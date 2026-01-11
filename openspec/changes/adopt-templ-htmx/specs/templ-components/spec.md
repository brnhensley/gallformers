## ADDED Requirements

### Requirement: Templ components MUST be type-safe

All Templ components MUST accept typed parameters and produce compile-time errors for invalid usage.

#### Scenario: Component with typed data
- Given a GallPage component accepting GallData struct
- When the component is invoked with correct data
- Then it compiles successfully
- And renders the expected HTML

#### Scenario: Missing required field
- Given a component requires a Species field
- When invoked without that field
- Then the Go compiler produces an error
- And the build fails before runtime

### Requirement: Layout components MUST use composition

Templ layouts MUST use the `{ children... }` pattern for content injection.

#### Scenario: Base layout with content
- Given a Base layout component
- When a page component uses `@Base(title) { ... }`
- Then the page content appears inside the layout structure
- And the title is used in the HTML head

#### Scenario: Nested layouts
- Given Public layout extends Base layout
- When a page uses Public layout
- Then both layout wrappers are applied correctly

### Requirement: HTMX partial responses MUST be fragments

HTMX partial handlers MUST return HTML fragments, not full documents.

#### Scenario: Partial returns fragment only
- Given an HTMX request to `/partials/gall/123`
- When the handler responds
- Then it returns only the component HTML
- And does NOT include `<!DOCTYPE>`, `<html>`, or `<head>` elements

#### Scenario: Full page returns complete document
- Given a regular request to `/gall/123`
- When the handler responds
- Then it returns a complete HTML document
- And includes proper `<!DOCTYPE html>` declaration

### Requirement: Form components MUST support HTMX attributes

Form components MUST allow HTMX attributes for dynamic behavior.

#### Scenario: Input with HTMX validation
- Given an Input component rendered in a form
- When it includes `hx-get` and `hx-trigger` attributes
- Then those attributes appear on the rendered input element
- And HTMX can trigger validation requests

#### Scenario: Form with HTMX submission
- Given a form with `hx-post` attribute
- When the form is submitted
- Then HTMX handles the submission
- And the response is swapped into the target element

### Requirement: Loading states MUST use HTMX indicators

Loading states MUST be implemented using HTMX's indicator pattern.

#### Scenario: Loading indicator display
- Given an element with `hx-indicator="#loading"`
- When an HTMX request is in progress
- Then the element with id "loading" becomes visible
- And has the `htmx-request` class applied

#### Scenario: Loading indicator hidden
- Given an HTMX request completes
- When the response is received
- Then the loading indicator is hidden
- And the `htmx-request` class is removed

### Requirement: Component accessibility MUST be preserved

Templ components MUST maintain accessibility standards.

#### Scenario: Form label association
- Given an Input component with label text
- When rendered
- Then the label element has `for` attribute matching input `id`

#### Scenario: Button semantics
- Given a Button component
- When rendered
- Then it uses semantic `<button>` element
- And has appropriate `type` attribute

#### Scenario: ARIA attributes for dynamic content
- Given a container that updates via HTMX
- When it is loading
- Then it has `aria-busy="true"`
- And an `aria-live` region announces changes

### Requirement: Alpine.js components MUST be declarative

Admin features using Alpine.js MUST use declarative `x-data` patterns.

#### Scenario: Tag editor initialization
- Given a tag editor component
- When rendered
- Then it has `x-data` attribute with initial state
- And tag list is bound to Alpine state

#### Scenario: Alpine state isolation
- Given multiple Alpine components on a page
- When one component's state changes
- Then other components are not affected
- And each maintains independent state

### Requirement: Images MUST use lazy loading

Images in galleries and lists MUST use native lazy loading to improve initial page load.

#### Scenario: Image with lazy loading
- Given an image in a gallery or list
- When the image is rendered
- Then it has `loading="lazy"` attribute
- And it has explicit `width` and `height` attributes to prevent layout shift

#### Scenario: Primary/hero image eager loading
- Given the primary image at the top of a species page
- When the image is rendered
- Then it does NOT have `loading="lazy"` (loads immediately)
- And it may have `fetchpriority="high"` for faster loading

### Requirement: Images MUST have meaningful alt text

All images MUST have alt text for accessibility.

#### Scenario: Species image alt text
- Given an image of a species
- When the image is rendered
- Then it has an `alt` attribute with format: "{species name} - {image caption if available}"
- And if no caption, alt is just the species name

#### Scenario: Gallery image alt text
- Given multiple images in a gallery
- When images are rendered
- Then each has unique alt text (e.g., "{species name} - image 1 of 5")
- And the primary image indicates it is the primary

#### Scenario: Decorative images
- Given a purely decorative image (icons, backgrounds)
- When the image is rendered
- Then it has `alt=""` (empty string, not missing)
- And it has `role="presentation"` if appropriate

### Requirement: JavaScript islands MUST be lazy-loaded

Complex JavaScript features MUST load only on pages that need them.

#### Scenario: Page without islands
- Given a species page with no range data
- When the page loads
- Then no island JavaScript files are loaded
- And only HTMX (14KB) is included

#### Scenario: Page with range map
- Given a species page with range data
- When the page loads
- Then the range-map island script loads
- And the map initializes with embedded data
