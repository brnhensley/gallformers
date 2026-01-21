# Tasks: V1 to V2 Cutover

## Status

**Repository restructure: COMPLETE** - V2 Phoenix code promoted to root, V1 archived in `v1/`.

**Remaining work**: DNS cutover execution and post-cutover cleanup.

## Prerequisites Checklist

Before starting cutover tasks, verify V2 is ready:

- [x] 0.1 Phoenix/LiveView application deployed to Fly.io
- [x] 0.2 V2 code promoted to repository root
- [x] 0.3 V1 code archived in `v1/` subdirectory
- [x] 0.4 CI workflows updated
- [ ] 0.5 All V2 functionality verified working on Fly.io

## 1. Pre-Cutover Preparation

### Documentation
- [ ] 1.1 Document current DO Droplet IP address
- [ ] 1.2 Document current Namecheap DNS configuration (screenshot)
- [ ] 1.3 Create cutover runbook with exact commands
- [ ] 1.4 Document Fly.io app name and region

### Automated Verification
- [ ] 1.5 Create smoke test script for critical paths
  - Health endpoint
  - Sample gall page (e.g., `/gall/1`)
  - Sample host page (e.g., `/host/1`)
  - Search endpoint
- [ ] 1.6 Test smoke script against V2 on Fly.io
- [ ] 1.7 Create database checksum comparison script
- [ ] 1.8 Check database size on DO: `ssh user@do-ip "ls -lh /mnt/gallformers_data/prisma/gallformers.sqlite"`
- [ ] 1.9 Perform dry run of cutover procedure (without DNS switch):
  - Download database from DO
  - Upload to Fly.io staging/test volume
  - Verify upload time and checksum process
  - Time the full procedure to validate estimates

### Auth0 Configuration
- [ ] 1.10 Document current Auth0 callback URLs
- [ ] 1.11 Add Fly.io callback URLs to Auth0 allowed list
- [ ] 1.12 Test admin login against V2 with new callbacks

### Maintenance Mode
- [ ] 1.13 Verify DO maintenance page exists and works
- [ ] 1.14 Test enabling/disabling maintenance mode on DO

### Fly.io Alerting
- [ ] 1.15 Set up CPU utilization alert (>80% sustained)
- [ ] 1.16 Set up memory utilization alert (>80%)
- [ ] 1.17 Set up HTTP 5xx error rate alert (>1% of requests)
- [ ] 1.18 Set up health check failure alert
- [ ] 1.19 Configure Slack integration for alerts
- [ ] 1.20 Test alert delivery

### User Communication
- [ ] 1.21 Add simple maintenance announcement banner to V1 site (deploy before T-7)
- [ ] 1.22 Draft maintenance window announcement text
- [ ] 1.23 Enable T-7 day notice on V1 site
- [ ] 1.24 Update to T-1 day reminder
- [ ] 1.25 (Optional) Post to iNaturalist gallformers project

### Repository Preparation
- [x] 1.26 Move V1 code into v1/ subdirectory ✅ COMPLETE
- [x] 1.27 Promote V2 Phoenix code to repository root ✅ COMPLETE
- [x] 1.28 Update CI workflows ✅ COMPLETE

## 2. Cutover Execution

### Phase 1: Freeze
- [ ] 2.1 Lower DNS TTL at Namecheap (48 hours before)
- [ ] 2.2 Enable maintenance mode on DO
- [ ] 2.3 Verify maintenance page is served
- [ ] 2.4 Record cutover start timestamp

### Phase 2: Database Sync
- [ ] 2.5 Create final backup on DO
- [ ] 2.6 Download database to local machine
- [ ] 2.7 Run Ecto migrations: `mix ecto.migrate`
- [ ] 2.8 Compute local checksum
- [ ] 2.9 Upload database to Fly.io volume
- [ ] 2.10 Set file permissions: `fly ssh console -a gallformers -C "chmod 644 /data/gallformers.sqlite"`
- [ ] 2.11 Verify checksum on Fly.io
- [ ] 2.12 Restart Fly.io app

### Phase 3: Pre-DNS Verification
- [ ] 2.13 Verify Fly.io health endpoint
- [ ] 2.14 Run smoke tests against fly.dev URL
- [ ] 2.15 Manual verification of admin login
- [ ] 2.16 Manual verification of public pages
- [ ] 2.17 Manual verification of image display

### Phase 4: DNS Switch
- [ ] 2.18 Update DNS at Namecheap (preserve any existing non-A records):
  - gallformers.org (ALIAS → gallformers.fly.dev)
  - gallformers.com (ALIAS → gallformers.fly.dev)
  - www.gallformers.org (CNAME → gallformers.fly.dev)
  - www.gallformers.com (CNAME → gallformers.fly.dev)
- [ ] 2.19 Run `fly certs add` for all four domains (brief SSL errors possible until certs provision)
- [ ] 2.20 Verify DNS propagation with `dig`
- [ ] 2.21 Wait for propagation (monitor with multiple DNS servers)

### Phase 5: Post-DNS Verification
- [ ] 2.22 Run smoke tests against production URL
- [ ] 2.23 Verify admin login via production URL
- [ ] 2.24 Monitor Fly.io logs for errors
- [ ] 2.25 Record cutover end timestamp
- [ ] 2.26 Calculate total downtime

## 3. Post-Cutover Monitoring

### T+1 Hour
- [ ] 3.1 Review Fly.io metrics dashboard
- [ ] 3.2 Check for error spikes in logs
- [ ] 3.3 Verify search functionality on production
- [ ] 3.4 Test admin create/edit/delete cycle
- [ ] 3.5 Disable AWS Lambda monitoring (it will alert on DO being down)

### T+24 Hours
- [ ] 3.6 Review overnight logs
- [ ] 3.7 Check for external referrer 404s
- [ ] 3.8 Verify all admin operations still working
- [ ] 3.9 Monitor user feedback channels

### T+7 Days
- [ ] 3.10 Final verification - all functionality working
- [ ] 3.11 Document any issues encountered during 7-day period

## 4. Cleanup

### Auth0
- [ ] 4.1 Remove DO callback URLs from Auth0 allowed list

### DNS
- [ ] 4.2 Reset DNS TTL to normal (3600 seconds)

### Digital Ocean
- [ ] 4.3 Create final archival backup of DO Droplet
- [ ] 4.4 Cancel DO Droplet
- [ ] 4.5 Document cost savings achieved

### AWS Lambda Monitoring
- [ ] 4.6 Delete AWS Lambda monitoring function (replaced by Fly.io alerts)

### Repository Cleanup
- [ ] 4.7 Create branch for v1/ directory removal
- [ ] 4.8 Remove v1/ directory entirely (all V1 code already archived there)
- [ ] 4.9 Verify CI/CD still works after removal
- [ ] 4.10 Merge cleanup to main

## 5. Rollback (if needed)

These tasks are only executed if issues are discovered:

- [ ] 5.1 Document issue requiring rollback
- [ ] 5.2 Revert DNS to DO Droplet IP at Namecheap
- [ ] 5.3 Wait for DNS propagation
- [ ] 5.4 Disable maintenance mode on DO
- [ ] 5.5 Verify DO site is serving traffic
- [ ] 5.6 Create incident report
- [ ] 5.7 Plan remediation and re-cutover
