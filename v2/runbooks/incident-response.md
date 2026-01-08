# Runbook: Incident Response

## Purpose
Coordinate response to a production incident affecting service availability.

## When to Use
- Complete service outage
- Partial outage affecting critical functionality
- Data integrity incident
- Security incident

## Severity Levels

| Level | Description | Response Time |
|-------|-------------|---------------|
| SEV1 | Complete outage, no users can access service | Immediate |
| SEV2 | Major feature broken, significant user impact | < 30 minutes |
| SEV3 | Minor feature broken, limited user impact | < 4 hours |

## Procedure

### 1. Acknowledge and Assess

Record:
- [ ] Time incident detected: `____:____`
- [ ] How detected (alert/user report/other): `____________`
- [ ] Initial symptoms: `____________`
- [ ] Severity level: `SEV__`

### 2. Communicate Status

If public-facing impact:
- Update status page (TODO: Upptime setup pending - see define-v2-foundation task 12)
- Acknowledge user reports

### 3. Diagnose

Run through [Diagnose Deployment Issue](./diagnose-deployment-issue.md).

Quick checks:

```bash
# Health
curl -s -o /dev/null -w "%{http_code}" https://gallformers-v2.fly.dev/health

# Status
fly status -a gallformers-v2

# Recent logs
fly logs -a gallformers-v2 --no-tail | head -100
```

### 4. Mitigate

Choose appropriate action based on diagnosis:

| Cause | Action |
|-------|--------|
| Bad deployment | [Rollback Deployment](./rollback-deployment.md) |
| Database issue | [Restore Database](./restore-database.md) |
| Infrastructure (Fly.io) | Check [Fly.io Status](https://status.fly.io) |
| Unknown | Continue to Step 5 |

### 5. Escalate If Needed

If not resolved within 15 minutes:
- Escalate to project owner
- Document what has been tried

### 6. Verify Resolution

- [ ] Health check returns 200
- [ ] Key user flows work
- [ ] Error rate returned to baseline
- [ ] Logs show clean operation

### 7. Communicate Resolution

- Update status page (when available)
- Respond to user reports
- Note time of resolution: `____:____`

## Post-Incident

Complete within 48 hours of resolution:

### Incident Report

Document:
1. **Timeline**: When detected, when resolved, key actions taken
2. **Impact**: Users affected, duration, data loss (if any)
3. **Root cause**: What caused the incident
4. **Resolution**: How it was fixed
5. **Prevention**: What changes will prevent recurrence

### Follow-up Actions

- [ ] Create issues for preventive measures
- [ ] Update runbooks if gaps identified
- [ ] Review monitoring/alerting coverage
- [ ] Share learnings with team

## Emergency Contacts

| Role | Contact |
|------|---------|
| Project Owner | (add contact) |
| Fly.io Support | support@fly.io |

## Quick Reference

```bash
# Health check
curl https://gallformers-v2.fly.dev/health

# App status
fly status -a gallformers-v2

# Recent logs
fly logs -a gallformers-v2 --no-tail

# List releases (for rollback)
fly releases -a gallformers-v2

# Fly.io status page
open https://status.fly.io
```
