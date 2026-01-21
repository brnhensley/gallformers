# common-components Specification

## Purpose
We want to use standard Phoenix components where we can, but we also know that we want consistent and more complex 
behaviors so we will need to create our own components.
## Requirements
### Requirement: Form Input Component

The system SHALL provide a reusable Input component for text, number, and email inputs.

#### Scenario: Input with label
- **WHEN** Input component is rendered with label prop
- **THEN** label text is displayed above the input
- **AND** label is associated with input via htmlFor/id

#### Scenario: Required input indicator
- **WHEN** Input component has required=true
- **THEN** red asterisk (*) appears after label text

#### Scenario: Input error state
- **WHEN** Input component has error prop with message
- **THEN** error message appears below input in red text
- **AND** input border is styled red

#### Scenario: Input two-way binding
- **WHEN** user types in input field
- **THEN** bound value updates reactively

### Requirement: Textarea Component

The system SHALL provide a reusable Textarea component for multi-line text input.

#### Scenario: Textarea with label
- **WHEN** Textarea component is rendered with label prop
- **THEN** label text is displayed above the textarea
- **AND** label is associated with textarea

#### Scenario: Textarea rows
- **WHEN** Textarea has rows prop set
- **THEN** textarea displays with specified number of rows

#### Scenario: Textarea error state
- **WHEN** Textarea component has error prop with message
- **THEN** error message appears below textarea in red text
- **AND** textarea border is styled red

#### Scenario: Textarea two-way binding
- **WHEN** user types in textarea
- **THEN** bound value updates reactively

### Requirement: Select Component

The system SHALL provide a reusable Select component for single-value dropdowns.

#### Scenario: Select renders options
- **WHEN** Select component receives options array
- **THEN** each option is rendered in dropdown
- **AND** optionLabel and optionValue props determine display/value

#### Scenario: Select placeholder
- **WHEN** Select has no value selected
- **THEN** placeholder "Select..." is shown

### Requirement: Checkbox Component

The system SHALL provide a reusable Checkbox component for boolean toggles.

#### Scenario: Checkbox toggle
- **WHEN** user clicks checkbox
- **THEN** checked state toggles
- **AND** bound value updates reactively

#### Scenario: Checkbox with label
- **WHEN** Checkbox rendered with label prop
- **THEN** label appears beside checkbox
- **AND** clicking label toggles checkbox

### Requirement: MultiSelect Component

The system SHALL provide a MultiSelect component for selecting multiple values from a list.

#### Scenario: MultiSelect toggle selection
- **WHEN** user clicks an unselected option
- **THEN** option is added to selected array
- **AND** option appears selected (highlighted)

#### Scenario: MultiSelect deselect
- **WHEN** user clicks a selected option
- **THEN** option is removed from selected array
- **AND** option appears unselected

### Requirement: Typeahead Component

The system SHALL provide a Typeahead component for async search and selection.

#### Scenario: Typeahead search
- **WHEN** user types in typeahead input
- **THEN** searchFn is called with query after debounce
- **AND** results appear in dropdown

#### Scenario: Typeahead selection
- **WHEN** user selects item from dropdown
- **THEN** selected value updates
- **AND** dropdown closes

#### Scenario: Typeahead multi-select
- **WHEN** Typeahead has multiple=true
- **THEN** user can select multiple items
- **AND** selected items appear as chips/tags

#### Scenario: Typeahead create new
- **WHEN** Typeahead has creatable=true and user types non-matching value
- **THEN** "Create new" option appears
- **AND** selecting it adds new value to selection

### Requirement: Button Component

The system SHALL provide a Button component with multiple style variants.

#### Scenario: Primary button
- **WHEN** Button has variant="primary"
- **THEN** button has brand maroon background with white text

#### Scenario: Secondary button
- **WHEN** Button has variant="secondary"
- **THEN** button has white background with gray border

#### Scenario: Danger button
- **WHEN** Button has variant="danger"
- **THEN** button has red background with white text

#### Scenario: Ghost button
- **WHEN** Button has variant="ghost"
- **THEN** button has transparent background with maroon text

#### Scenario: Disabled button
- **WHEN** Button has disabled=true
- **THEN** button appears faded
- **AND** click events are not fired

#### Scenario: Autofocus button
- **WHEN** Button has autofocus=true
- **THEN** button receives focus when mounted

### Requirement: Modal Component

The system SHALL provide a Modal component for dialog overlays.

#### Scenario: Modal open/close
- **WHEN** Modal open prop is true
- **THEN** modal is visible with backdrop
- **WHEN** open prop becomes false
- **THEN** modal is hidden

#### Scenario: Modal escape key
- **WHEN** user presses Escape while modal is open
- **THEN** modal closes

#### Scenario: Modal click outside
- **WHEN** user clicks backdrop outside modal content
- **THEN** modal closes

#### Scenario: Modal title
- **WHEN** Modal has title prop
- **THEN** title appears at top of modal content

### Requirement: Confirm Modal Component

The system SHALL provide a ConfirmModal for destructive action confirmation with specific UX.

#### Scenario: Cancel button focus
- **WHEN** ConfirmModal opens
- **THEN** Cancel button receives focus by default

#### Scenario: Confirm button styling
- **WHEN** ConfirmModal has variant="danger"
- **THEN** Confirm button uses danger/red styling
- **AND** Cancel button uses secondary styling

#### Scenario: Confirm action
- **WHEN** user clicks Confirm button
- **THEN** onConfirm callback is invoked

#### Scenario: Cancel action
- **WHEN** user clicks Cancel button or presses Escape
- **THEN** onCancel callback is invoked
- **AND** modal closes

### Requirement: Card Component

The system SHALL provide a Card component for grouped content sections.

#### Scenario: Card with title
- **WHEN** Card has title prop
- **THEN** title appears at top of card

#### Scenario: Card without title
- **WHEN** Card has no title prop
- **THEN** content renders without title header

### Requirement: Alert Component

The system SHALL provide an Alert component for inline messages.

#### Scenario: Alert variants
- **WHEN** Alert has variant="info"
- **THEN** alert has blue styling
- **WHEN** Alert has variant="warning"
- **THEN** alert has yellow styling
- **WHEN** Alert has variant="error"
- **THEN** alert has red styling
- **WHEN** Alert has variant="success"
- **THEN** alert has green styling

### Requirement: Spinner Component

The system SHALL provide a Spinner component for loading states.

#### Scenario: Spinner sizes
- **WHEN** Spinner has size="sm"
- **THEN** spinner is small (16px)
- **WHEN** Spinner has size="md"
- **THEN** spinner is medium (32px)
- **WHEN** Spinner has size="lg"
- **THEN** spinner is large (48px)

### Requirement: Table Component

The system SHALL provide a Table component for displaying tabular data with sorting and pagination.

#### Scenario: Table renders data
- **WHEN** Table receives data and columns props
- **THEN** each row renders with column values

#### Scenario: Table sortable columns
- **WHEN** column has sortable=true
- **THEN** clicking header triggers onsort callback
- **AND** sort direction indicator shows

#### Scenario: Table custom cell render
- **WHEN** column has render function
- **THEN** render function output is displayed instead of raw value

#### Scenario: Table pagination display
- **WHEN** totalCount exceeds pageSize
- **THEN** pagination controls appear below table
- **AND** "Showing X to Y of Z results" text displays
- **AND** Previous/Next buttons are visible

#### Scenario: Table pagination hidden
- **WHEN** totalCount is less than or equal to pageSize
- **THEN** pagination controls are not displayed

#### Scenario: Table page navigation
- **WHEN** user clicks Next button
- **THEN** onpagechange callback is invoked with next page number
- **WHEN** user clicks Previous button
- **THEN** onpagechange callback is invoked with previous page number

#### Scenario: Table pagination boundaries
- **WHEN** user is on first page
- **THEN** Previous button is disabled
- **WHEN** user is on last page
- **THEN** Next button is disabled

### Requirement: Range Map Component

The system SHALL provide a RangeMap component for displaying geographic distribution.

#### Scenario: View-only map
- **WHEN** RangeMap has editable=false (default)
- **THEN** states in inRange set are filled green
- **AND** states not in inRange are filled white
- **AND** clicking states has no effect

#### Scenario: Editable map
- **WHEN** RangeMap has editable=true
- **THEN** clicking a state calls onToggle callback with state code
- **AND** cursor shows pointer on hover

#### Scenario: Excluded range display
- **WHEN** state code is in excludedRange set
- **THEN** state is filled with coral/red color

### Requirement: Toast Notification System

The system SHALL provide a toast notification system for feedback messages.

#### Scenario: Success toast
- **WHEN** toast.success(message) is called
- **THEN** green toast appears with message

#### Scenario: Error toast
- **WHEN** toast.error(message) is called
- **THEN** red toast appears with message

#### Scenario: Info toast
- **WHEN** toast.info(message) is called
- **THEN** blue toast appears with message

#### Scenario: Toast auto-dismiss
- **WHEN** toast is displayed
- **THEN** toast automatically disappears after 5 seconds

#### Scenario: Toast manual dismiss
- **WHEN** user clicks close button on toast
- **THEN** toast is immediately removed

#### Scenario: Multiple toasts
- **WHEN** multiple toasts are triggered
- **THEN** toasts stack vertically
- **AND** each dismisses independently

### Requirement: Component Accessibility

The system SHALL ensure all components meet basic accessibility requirements.

#### Scenario: Form labels
- **WHEN** any form component (Input, Select, Checkbox) is rendered
- **THEN** label element is associated with input via for/id attributes

#### Scenario: Keyboard navigation
- **WHEN** user navigates with Tab key
- **THEN** all interactive elements are focusable in logical order

#### Scenario: Focus visibility
- **WHEN** interactive element receives focus
- **THEN** focus ring is visible

#### Scenario: Button semantics
- **WHEN** Button component is rendered
- **THEN** it uses semantic `<button>` element
- **AND** has appropriate type attribute
