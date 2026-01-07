# Capability: articles

In-app authoring and display of reference articles (guides, keys, FAQs).

## ADDED Requirements

### Requirement: Article Storage

The system SHALL store articles in the database with markdown content, metadata, and publication status.

#### Scenario: Article data structure

- **WHEN** an article is created
- **THEN** the system SHALL store id, slug, title, author, description, content, tags, is_published, created_at, updated_at
- **AND** published_at SHALL be set when is_published becomes true

### Requirement: Article Listing

The system SHALL provide a paginated list of articles with filtering based on authentication status.

#### Scenario: Unauthenticated user views article list

- **WHEN** an unauthenticated user requests GET /api/v1/articles
- **THEN** the system SHALL return only articles where is_published is true
- **AND** draft articles SHALL NOT be included

#### Scenario: Authenticated user views article list

- **WHEN** an authenticated user requests GET /api/v1/articles
- **THEN** the system SHALL return all articles (published and drafts)

#### Scenario: Filter articles by tag

- **WHEN** a user requests GET /api/v1/articles?tag=guide
- **THEN** the system SHALL return only articles containing the specified tag

#### Scenario: Paginated results

- **WHEN** a user requests GET /api/v1/articles with limit and offset parameters
- **THEN** the system SHALL return at most limit articles starting from offset
- **AND** the response SHALL include total count, limit, offset, and has_more flag

#### Scenario: Default sort order

- **WHEN** a user requests GET /api/v1/articles without sort parameter
- **THEN** the system SHALL return articles sorted by newest first
- **AND** the sort SHALL use published_at for published articles and created_at for drafts

### Requirement: Article Retrieval

The system SHALL allow retrieval of individual articles by slug with access control.

#### Scenario: View published article

- **WHEN** a user requests GET /api/v1/articles/{slug} for a published article
- **THEN** the system SHALL return the full article including content

#### Scenario: View draft article unauthenticated

- **WHEN** an unauthenticated user requests GET /api/v1/articles/{slug} for a draft article
- **THEN** the system SHALL return 404 Not Found

#### Scenario: View draft article authenticated

- **WHEN** an authenticated user requests GET /api/v1/articles/{slug} for a draft article
- **THEN** the system SHALL return the full article including content

### Requirement: Article Creation

The system SHALL allow authenticated users to create new articles.

#### Scenario: Create article with required fields

- **WHEN** an authenticated user POSTs to /api/v1/articles with title and author
- **THEN** the system SHALL create the article with a generated slug
- **AND** the system SHALL return the created article with 201 status

#### Scenario: Create article unauthenticated

- **WHEN** an unauthenticated user POSTs to /api/v1/articles
- **THEN** the system SHALL return 401 Unauthorized

#### Scenario: Slug generation

- **WHEN** an article is created with title "My Article Title"
- **THEN** the system SHALL generate slug "my-article-title"
- **AND** the system SHALL append a number if slug already exists

### Requirement: Article Update

The system SHALL allow authenticated users to update existing articles.

#### Scenario: Update article content

- **WHEN** an authenticated user PUTs to /api/v1/articles/{slug} with new content
- **THEN** the system SHALL update the article
- **AND** the system SHALL set updated_at to current time

#### Scenario: Publish draft article

- **WHEN** an authenticated user updates an article setting is_published to true
- **THEN** the system SHALL set published_at to current time (if not already set)
- **AND** the article SHALL become visible to unauthenticated users

#### Scenario: Unpublish article

- **WHEN** an authenticated user updates an article setting is_published to false
- **THEN** the system SHALL retain the existing published_at value
- **AND** the article SHALL no longer be visible to unauthenticated users

### Requirement: Article Deletion

The system SHALL allow authenticated users to delete articles.

#### Scenario: Delete article

- **WHEN** an authenticated user DELETEs /api/v1/articles/{slug}
- **THEN** the system SHALL remove the article
- **AND** the system SHALL return 204 No Content

### Requirement: Tag Management

The system SHALL track and list article tags with counts.

#### Scenario: List tags with counts

- **WHEN** a user requests GET /api/v1/articles/tags
- **THEN** the system SHALL return all unique tags with article counts
- **AND** unauthenticated users SHALL see counts for published articles only

### Requirement: Markdown Rendering

The system SHALL render article content from markdown to HTML safely.

#### Scenario: Render markdown content

- **WHEN** an article with markdown content is displayed
- **THEN** the system SHALL render headings, paragraphs, lists, links, and code blocks
- **AND** the HTML SHALL be sanitized to prevent XSS attacks

#### Scenario: GitHub-flavored markdown

- **WHEN** an article contains GFM features (tables, strikethrough, task lists)
- **THEN** the system SHALL render them correctly

### Requirement: Author Attribution

The system SHALL track authorship with flexibility for custom attribution.

#### Scenario: Author is required

- **WHEN** an authenticated user creates an article
- **THEN** the system SHALL require an author field
- **AND** the client SHALL pre-fill with the logged-in user's display name
- **AND** the user MAY change the author value before submitting
