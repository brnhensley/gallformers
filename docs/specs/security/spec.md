# security Specification

## Purpose
TBD - created by archiving change fix-security-critical. Update Purpose after archive.
## Requirements
### Requirement: Authentication Enforcement

Protected API endpoints SHALL terminate request processing immediately upon authentication failure.

#### Scenario: Unauthenticated request to protected endpoint

- **WHEN** a request is made to a protected endpoint without valid session
- **THEN** the server SHALL respond with HTTP 401 status
- **AND** the server SHALL NOT execute any endpoint logic
- **AND** the server SHALL NOT access database resources

#### Scenario: Authenticated request to protected endpoint

- **WHEN** a request is made to a protected endpoint with valid session
- **THEN** the server SHALL proceed with endpoint logic
- **AND** the server SHALL execute the requested operation

### Requirement: SQL Query Parameterization

All database queries with dynamic values SHALL use parameterized queries to prevent SQL injection.

#### Scenario: Numeric ID in query

- **WHEN** a database query includes a user-provided numeric ID
- **THEN** the query SHALL use parameterized binding (not string interpolation)
- **AND** the parameter SHALL be validated as the expected type

#### Scenario: String value in query

- **WHEN** a database query includes a user-provided string value
- **THEN** the query SHALL use parameterized binding (not string interpolation)
- **AND** the value SHALL be escaped by the database driver
- **AND** string concatenation into SQL SHALL NOT be used

#### Scenario: Batch operations

- **WHEN** a database operation involves multiple dynamic values
- **THEN** each value SHALL be individually parameterized
- **AND** the query builder SHALL handle escaping for all values

### Requirement: Credential Security

Application secrets and credentials SHALL NOT be stored in version control.

#### Scenario: Environment files excluded

- **WHEN** the repository is cloned
- **THEN** `.env`, `.env.local`, and `prisma/.env` SHALL NOT be present
- **AND** these patterns SHALL be listed in `.gitignore`

#### Scenario: Credential exposure check

- **WHEN** checking for credential exposure
- **THEN** git history SHALL NOT contain environment files with secrets
- **AND** if found, credentials SHALL be rotated immediately

