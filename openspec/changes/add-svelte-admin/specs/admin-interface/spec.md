## ADDED Requirements

### Requirement: Admin Page Authentication

The system SHALL require authentication for all admin pages.

#### Scenario: Unauthenticated access to admin page
- **WHEN** unauthenticated user navigates to any `/admin/*` route
- **THEN** user is redirected to login page
- **AND** redirect URL includes original destination for post-login redirect

#### Scenario: Authenticated admin access
- **WHEN** authenticated user with Admin role navigates to admin page
- **THEN** page loads normally
- **AND** admin navigation is visible

#### Scenario: Non-admin authenticated user
- **WHEN** authenticated user without Admin role navigates to admin page
- **THEN** access is denied
- **AND** appropriate error message is displayed

### Requirement: Super Admin Page Protection

The system SHALL restrict certain admin pages to Super Admin users only.

#### Scenario: Super Admin accesses protected page
- **WHEN** Super Admin navigates to Taxonomy, Place, FilterTerms, or Species direct edit page
- **THEN** page loads normally with full functionality

#### Scenario: Regular Admin accesses Super Admin page
- **WHEN** regular Admin navigates to Taxonomy, Place, FilterTerms, or Species direct edit page
- **THEN** access denied message is displayed
- **AND** user cannot view or modify data

### Requirement: Destructive Operation Confirmation

The system SHALL require confirmation before destructive operations with specific UX requirements.

#### Scenario: Delete confirmation modal
- **WHEN** user clicks delete button for any entity
- **THEN** confirmation modal appears with danger variant styling
- **AND** message explains what will be deleted including cascade effects
- **AND** Cancel button is focused by default
- **AND** Confirm button uses danger/red styling

#### Scenario: Delete confirmation cancelled
- **WHEN** user clicks Cancel or presses Escape in delete confirmation
- **THEN** modal closes
- **AND** no deletion occurs
- **AND** entity remains unchanged

#### Scenario: Delete confirmation accepted
- **WHEN** user clicks Confirm in delete confirmation
- **THEN** entity is deleted
- **AND** success toast notification appears
- **AND** UI updates to reflect deletion

### Requirement: Form Validation Display

The system SHALL display validation errors inline with form fields.

#### Scenario: Required field empty
- **WHEN** user submits form with empty required field
- **THEN** error message appears below the field
- **AND** error message is red text
- **AND** form is not submitted

#### Scenario: Multiple validation errors
- **WHEN** user submits form with multiple validation errors
- **THEN** all errors are displayed simultaneously
- **AND** each error appears below its respective field

#### Scenario: Validation error cleared
- **WHEN** user corrects a field with validation error and leaves the field (blur)
- **THEN** error message is removed
- **AND** validation runs on blur for immediate feedback

### Requirement: Entity CRUD Operations

The system SHALL provide create, read, update, and delete operations for all admin entities.

#### Scenario: Create new entity
- **WHEN** user fills required fields and clicks Save
- **THEN** entity is created in database
- **AND** success toast notification appears
- **AND** entity becomes the selected item in the form

#### Scenario: Update existing entity
- **WHEN** user selects existing entity, modifies fields, and clicks Save
- **THEN** entity is updated in database
- **AND** success toast notification appears
- **AND** form reflects saved values

#### Scenario: API error during save
- **WHEN** API returns error during create/update
- **THEN** error toast notification appears with error message
- **AND** form data is preserved
- **AND** user can retry

### Requirement: Entity Search Typeahead

The system SHALL provide typeahead search for entity selection.

#### Scenario: Search with results
- **WHEN** user types in entity search field
- **THEN** matching entities appear in dropdown after debounce (library default)
- **AND** results are filtered as user types
- **AND** user can select from dropdown

#### Scenario: Search with no results
- **WHEN** user types search term with no matches
- **THEN** dropdown shows "No results found" message
- **AND** user can clear and try again

#### Scenario: Create new from search
- **WHEN** user types name that doesn't exist and selects "Create new"
- **THEN** form switches to create mode with name pre-filled
- **AND** user can fill remaining fields

### Requirement: Admin Navigation

The system SHALL provide consistent navigation across admin pages.

#### Scenario: Navigation highlights current page
- **WHEN** user is on an admin page
- **THEN** corresponding nav item is visually highlighted

#### Scenario: Super Admin nav items
- **WHEN** Super Admin views admin navigation
- **THEN** Super Admin section is visible with Taxonomy, Place, FilterTerms links

#### Scenario: Regular Admin nav items
- **WHEN** regular Admin views admin navigation
- **THEN** Super Admin section is not visible
- **AND** only standard admin links are shown
