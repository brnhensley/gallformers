## ADDED Requirements

### Requirement: Database Migration

The cutover process SHALL synchronize the production database from the v1 Digital Ocean environment to the v2 Fly.io environment with zero data loss.

#### Scenario: Database sync during maintenance window
- **WHEN** the cutover process begins
- **AND** v1 is placed in maintenance mode
- **THEN** no database writes occur on v1
- **AND** the SQLite database file is copied to the local machine
- **AND** a SHA-256 checksum is computed
- **AND** the file is uploaded to Fly.io persistent volume
- **AND** the checksum is verified on Fly.io
- **AND** checksums match exactly

#### Scenario: Database integrity verification
- **WHEN** the database is uploaded to Fly.io
- **THEN** the v2 application can start successfully
- **AND** health endpoint returns 200
- **AND** sample queries return expected data

### Requirement: DNS Cutover

The cutover process SHALL redirect all four domains (gallformers.org, gallformers.com, www.gallformers.org, www.gallformers.com) from the v1 Digital Ocean Droplet to the v2 Fly.io application.

#### Scenario: DNS preparation
- **WHEN** cutover is scheduled
- **THEN** DNS TTL is lowered to 300 seconds at least 24 hours before cutover
- **AND** current DNS configuration is documented for rollback

#### Scenario: DNS switch execution
- **WHEN** database sync is verified successful
- **THEN** Namecheap DNS records for all four domains are updated to point to Fly.io
- **AND** existing non-A records (TXT, etc.) are preserved
- **AND** propagation is verified using DNS lookup tools

#### Scenario: DNS propagation verification
- **WHEN** DNS records are updated
- **THEN** the production URL (https://gallformers.org) serves the v2 application
- **AND** SSL certificates are valid

### Requirement: Rollback Capability

The cutover process SHALL maintain rollback capability for 7 days after cutover.

#### Scenario: Rollback preparation
- **WHEN** cutover completes
- **THEN** the v1 Digital Ocean Droplet remains running but receives no traffic
- **AND** the v1 database backup is preserved
- **AND** rollback procedure is documented

#### Scenario: Rollback execution
- **WHEN** critical issues are discovered within 7 days
- **THEN** DNS records can be reverted to the v1 Droplet IP
- **AND** v1 resumes serving traffic within 15 minutes
- **AND** any data created in v2 after cutover will be lost (documented as known limitation)

### Requirement: Verification Checklist

The cutover process SHALL verify all critical functionality before completing.

#### Scenario: Automated smoke tests
- **WHEN** database sync completes
- **THEN** health endpoint returns 200
- **AND** sample public pages return 200 (gall, host, family, genus)
- **AND** search endpoint returns valid results
- **AND** API endpoints respond correctly

#### Scenario: Manual verification
- **WHEN** automated tests pass
- **THEN** admin login is tested manually
- **AND** CRUD operations are verified
- **AND** image display is verified
- **AND** reference article rendering is verified

### Requirement: V1 Deprecation

The cutover process SHALL remove v1 infrastructure after the verification period.

#### Scenario: Post-verification cleanup
- **WHEN** 7 days pass without rollback
- **THEN** v1 callback URLs are removed from Auth0
- **AND** DNS TTL is reset to normal (3600 seconds)
- **AND** Digital Ocean Droplet is cancelled
- **AND** cost savings are documented

#### Scenario: Repository cleanup
- **WHEN** infrastructure deprecation completes
- **THEN** v1 code directories are removed from the repository
- **AND** v1 configuration files are removed
- **AND** documentation is updated for v2
- **AND** CI/CD workflows are updated for v2 only

### Requirement: Downtime Target

The cutover process SHALL minimize user-facing downtime.

#### Scenario: Downtime measurement
- **WHEN** cutover executes
- **THEN** total downtime (maintenance mode enabled to production URL verified) is less than 30 minutes
- **AND** target downtime is less than 10 minutes

#### Scenario: Downtime communication
- **WHEN** maintenance mode is enabled
- **THEN** users see a maintenance page (not an error)
- **AND** the page indicates the site will return shortly
