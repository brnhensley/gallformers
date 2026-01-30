# Runbook: Set Up Monitoring Alerts

## Purpose
Configure Grafana alerts in Fly.io's managed metrics system to detect resource and error issues before they cause outages.

## Prerequisites
- Fly.io account with deployed app
- Access to fly-metrics.net (automatic with Fly.io auth)

## Alerts to Configure

| Alert | Threshold | Purpose |
|-------|-----------|---------|
| High CPU | >80% for 5 minutes | Detect sustained CPU pressure |
| High Memory | >80% utilization | Detect memory pressure before OOM |
| HTTP 5xx Errors | >1% of requests | Detect application errors |

## Procedure

### 1. Access Grafana

1. Go to [fly-metrics.net](https://fly-metrics.net)
2. Log in with your Fly.io credentials
3. Select your organization if prompted

### 2. Set Up Contact Point (Email Notifications)

1. Navigate to **Alerting** > **Contact points**
2. Click **Add contact point**
3. Configure:
   - **Name**: `Email - Primary`
   - **Integration**: Email
   - **Addresses**: Your email address
4. Click **Save contact point**
5. Click **Test** to verify delivery

### 3. Create Alert Rules

Navigate to **Alerting** > **Alert rules** > **Create alert rule**

#### Alert: High CPU Usage

**Query:**
```promql
100 - (avg by (app) (rate(fly_instance_cpu{app="gallformers", mode="idle"}[5m])) * 100)
```

**Configuration:**
- **Rule name**: `Gallformers - High CPU`
- **Folder**: Create or select `Gallformers`
- **Evaluate every**: `1m`
- **For**: `5m` (sustained threshold)
- **Condition**: Is above `80`
- **Contact point**: `Email - Primary`

**Annotations:**
- **Summary**: `CPU usage above 80% on Gallformers`
- **Description**: `CPU has been above 80% for 5 minutes. Check for runaway processes or consider scaling.`

#### Alert: High Memory Usage

**Query:**
```promql
100 * (1 - (avg by (app) (fly_instance_memory_mem_available{app="gallformers"}) / avg by (app) (fly_instance_memory_mem_total{app="gallformers"})))
```

**Configuration:**
- **Rule name**: `Gallformers - High Memory`
- **Folder**: `Gallformers`
- **Evaluate every**: `1m`
- **For**: `5m`
- **Condition**: Is above `80`
- **Contact point**: `Email - Primary`

**Annotations:**
- **Summary**: `Memory usage above 80% on Gallformers`
- **Description**: `Memory utilization has been above 80% for 5 minutes. Risk of OOM. Check for memory leaks or consider scaling.`

#### Alert: HTTP 5xx Error Rate

**Query:**
```promql
100 * sum(rate(fly_app_http_responses_count{app="gallformers", status=~"5.."}[5m])) / sum(rate(fly_app_http_responses_count{app="gallformers"}[5m]))
```

**Configuration:**
- **Rule name**: `Gallformers - High Error Rate`
- **Folder**: `Gallformers`
- **Evaluate every**: `1m`
- **For**: `2m` (errors need faster response)
- **Condition**: Is above `1`
- **Contact point**: `Email - Primary`

**Annotations:**
- **Summary**: `HTTP 5xx error rate above 1% on Gallformers`
- **Description**: `More than 1% of requests are returning 5xx errors. Check application logs: fly logs -a gallformers`

### 4. Verify Alert Configuration

1. Navigate to **Alerting** > **Alert rules**
2. Confirm all three rules appear under the `Gallformers` folder
3. Check status shows `Normal` (green) for each rule
4. Verify notification routing is correct under **Alerting** > **Notification policies**

### 5. Test Alerts (Optional)

To test that alerts fire and notifications are delivered:

**Test High CPU:**
```bash
# SSH into the app and run a CPU stress test
fly ssh console -a gallformers
# Inside the container:
dd if=/dev/zero of=/dev/null &
dd if=/dev/zero of=/dev/null &
# Wait 5+ minutes, then kill the processes
killall dd
```

**Test Error Rate:**
Create a temporary endpoint that returns 500s, or check that the query returns data by running it in Grafana's Explore view.

## Troubleshooting

### No metrics appearing
- Ensure app has received traffic recently (metrics require active requests)
- Check that you're in the correct organization
- Verify app name matches exactly (`gallformers`)

### Alerts not firing
- Check **Alerting** > **Alert rules** for evaluation errors
- Verify the query returns data in **Explore** view
- Ensure "For" duration has elapsed

### Not receiving emails
- Check spam folder
- Verify contact point test succeeded
- Check **Alerting** > **Contact points** for delivery errors

## Related Resources

- [Fly.io Metrics Documentation](https://fly.io/docs/monitoring/metrics/)
- [Grafana Alerting Documentation](https://grafana.com/docs/grafana/latest/alerting/)
- [Status Page](https://jeffdc.github.io/gallformers-status/) - Upptime-based uptime monitoring
- [Incident Response Runbook](./incident-response.md)

## Monitoring Coverage Summary

| Check | Tool | Frequency |
|-------|------|-----------|
| Site availability | Upptime (gallformers-status) | Every 5 minutes |
| Health endpoint | Upptime (gallformers-status) | Every 5 minutes |
| CPU utilization | Grafana alert | Every 1 minute |
| Memory utilization | Grafana alert | Every 1 minute |
| HTTP error rate | Grafana alert | Every 1 minute |
