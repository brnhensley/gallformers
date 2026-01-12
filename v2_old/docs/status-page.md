# Gallformers Status Page

The Gallformers status page is hosted using [Upptime](https://upptime.js.org/), an open-source uptime monitor powered entirely by GitHub Actions and GitHub Pages.

## URLs

- **Status Page**: https://jeffdc.github.io/gallformers-status/
- **Repository**: https://github.com/jeffdc/gallformers-status

## Monitored Endpoints

The following endpoints are monitored every 5 minutes:

| Endpoint | URL | Purpose |
|----------|-----|---------|
| Gallformers V2 API | https://gallformers.fly.dev/health | API health check |
| Gallformers V2 Site | https://gallformers.fly.dev | Main v2 site availability |
| Gallformers (Production) | https://gallformers.org | Current production site |

## How It Works

1. **GitHub Actions** run every 5 minutes to check each endpoint
2. **Response times** are recorded and graphed over time
3. **Incidents** are automatically created as GitHub Issues when a site goes down
4. **GitHub Pages** hosts the static status page generated from the data

## Configuration

The status page is configured via `.upptimerc.yml` in the gallformers-status repo. Key settings:

```yaml
# Check frequency
workflowSchedule:
  uptime: "*/5 * * * *"        # Every 5 minutes
  responseTime: "*/5 * * * *"  # Every 5 minutes
  staticSite: "0 0 * * *"      # Daily rebuild
```

## Managing Incidents

### Automatic Incidents

When a monitored endpoint fails:
1. An issue is automatically created in the gallformers-status repo
2. The status page shows the incident
3. When the endpoint recovers, the issue is closed automatically

### Manual Incidents

To create a manual incident (e.g., planned maintenance):
1. Go to the gallformers-status repo
2. Create a new issue with the label `incident`
3. Use the title format: `🛑 [Endpoint Name]: Description`
4. The status page will display the incident

### Acknowledging Incidents

Add a comment to the incident issue to acknowledge it. The comment will appear in the incident timeline on the status page.

### Resolving Incidents

To resolve a manual incident, close the issue. Add a comment explaining the resolution.

## Adding New Endpoints

Edit `.upptimerc.yml` in the gallformers-status repo:

```yaml
sites:
  - name: New Endpoint Name
    url: https://example.com/endpoint
    expectedStatusCodes:
      - 200
```

Commit and push to master. The new endpoint will be monitored on the next check cycle.

## Repository Structure

```
gallformers-status/
├── .upptimerc.yml     # Main configuration
├── .github/
│   └── workflows/     # GitHub Actions workflows
├── api/               # JSON API data (auto-generated)
├── graphs/            # Response time graphs (auto-generated)
└── history/           # Historical uptime data (auto-generated)
```

## Troubleshooting

### Workflows Not Running

Check that GitHub Actions have write permissions:
1. Go to repo Settings > Actions > General
2. Under "Workflow permissions", select "Read and write permissions"
3. Click Save

### Pages Not Deploying

Verify GitHub Pages is configured:
1. Go to repo Settings > Pages
2. Source should be set to "Deploy from a branch"
3. Branch should be `gh-pages`

### False Positives

If a site is showing as down but is actually up:
1. Check the endpoint URL is correct
2. Verify expected status codes match what the endpoint returns
3. Check for rate limiting or IP blocking
