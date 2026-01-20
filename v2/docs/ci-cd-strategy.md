# CI/CD Strategy for Gallformers V2

This document defines the CI/CD pipeline strategy for the v2 rewrite.

## Overview

The v2 CI/CD pipeline consists of three workflows:

1. **CI (ci-v2.yml)**: Runs tests on all PRs and pushes affecting `v2/`
2. **Preview (preview-v2.yml)**: Deploys PR preview apps to Fly.io (label-gated)
3. **Deploy (deploy-v2.yml)**: Deploys to production Fly.io on push to main

## Test Database

A single seed database serves both CI tests and preview deployments:

```
v2/
├── testdata/
│   └── seed.sqlite      # Committed to repo (~5-10MB)
```

**Creating the seed database:**
1. Export sanitized subset of prod data, OR
2. Hand-craft representative test data
3. Commit to repo and update as schema evolves

**Usage:**
- CI: Tests run against `seed.sqlite`
- Preview apps: `seed.sqlite` is copied into the container

## PR Checks (ci-v2.yml)

### Trigger
```yaml
on:
  push:
    branches: [main]
    paths: ['v2/**']
  pull_request:
    branches: ['**']
    paths: ['v2/**']

concurrency:
  group: ci-v2-${{ github.ref }}
  cancel-in-progress: true
```

### Go API Checks (v2/api/)
| Check | Command | Purpose |
|-------|---------|---------|
| Format | `gofmt -l .` | Ensure code formatting |
| Vet | `go vet ./...` | Static analysis |
| Test | `go test ./... -v` | Run unit tests |
| Build | `go build ./cmd/server` | Verify compilation |

### Svelte Web Checks (v2/web/)
| Check | Command | Purpose |
|-------|---------|---------|
| Install | `npm ci` | Install dependencies |
| Lint | `npm run lint` | ESLint/Prettier checks |
| Check | `npm run check` | Svelte type checking |
| Build | `npm run build` | Verify static build |

### Full Workflow
```yaml
name: CI V2

on:
  push:
    branches: [main]
    paths: ['v2/**']
  pull_request:
    branches: ['**']
    paths: ['v2/**']

concurrency:
  group: ci-v2-${{ github.ref }}
  cancel-in-progress: true

jobs:
  api:
    name: Go API
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: v2/api
    steps:
      - uses: actions/checkout@v4

      - name: Setup Go
        uses: actions/setup-go@v5
        with:
          go-version: '1.25'

      - name: Check formatting
        run: |
          if [ -n "$(gofmt -l .)" ]; then
            echo "Code is not formatted. Run 'gofmt -w .'"
            gofmt -d .
            exit 1
          fi

      - name: Vet
        run: go vet ./...

      - name: Test
        run: go test ./... -v
        env:
          DATABASE_PATH: ../testdata/seed.sqlite

      - name: Build
        run: go build ./cmd/server

  web:
    name: Svelte Web
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: v2/web
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: v2/web/package-lock.json

      - name: Install dependencies
        run: npm ci

      - name: Lint
        run: npm run lint

      - name: Type check
        run: npm run check

      - name: Build
        run: npm run build
```

## Preview Deployments (preview-v2.yml)

Preview apps are created for PRs with the `preview` label.

### How It Works
- Uses [`superfly/fly-pr-review-apps`](https://github.com/superfly/fly-pr-review-apps)
- Creates app named `pr-{number}-jeffdc-gallformers`
- Available at `https://pr-{number}-jeffdc-gallformers.fly.dev`
- Automatically destroyed when PR is closed/merged

### Trigger
```yaml
on:
  pull_request:
    types: [opened, reopened, synchronize, closed]
    paths: ['v2/**']
```

### Full Workflow
```yaml
name: Preview V2

on:
  pull_request:
    types: [opened, reopened, synchronize, closed]
    paths: ['v2/**']

concurrency:
  group: preview-v2-${{ github.event.pull_request.number }}
  cancel-in-progress: true

jobs:
  preview:
    name: Deploy Preview
    runs-on: ubuntu-latest
    # Only run if PR has 'preview' label
    if: contains(github.event.pull_request.labels.*.name, 'preview')
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: v2/web/package-lock.json

      - name: Build web static files
        run: |
          cd v2/web
          npm ci
          npm run build

      - name: Copy seed database
        run: |
          mkdir -p v2/data
          cp v2/testdata/seed.sqlite v2/data/gallformers.sqlite

      - name: Deploy Preview App
        uses: superfly/fly-pr-review-apps@1.2.1
        with:
          config: v2/fly.toml
          name: pr-${{ github.event.pull_request.number }}-gallformers
        env:
          FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
```

### Adding Preview Label
To create a preview for a PR:
1. Open the PR on GitHub
2. Add the `preview` label
3. The workflow will trigger and deploy

## Production Deployment (deploy-v2.yml)

### Trigger
```yaml
on:
  push:
    branches: [main]
    paths: ['v2/**']
```

Deploys when:
- Code is pushed to `main` branch
- Changes are within the `v2/` directory
- CI checks have passed (enforced by branch protection)

### Full Workflow
```yaml
name: Deploy V2

on:
  push:
    branches: [main]
    paths: ['v2/**']

concurrency:
  group: deploy-v2
  cancel-in-progress: false  # Don't cancel production deploys

jobs:
  deploy:
    name: Deploy to Fly.io
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Go
        uses: actions/setup-go@v5
        with:
          go-version: '1.25'

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: v2/web/package-lock.json

      - name: Build web static files
        run: |
          cd v2/web
          npm ci
          npm run build

      - name: Setup Flyctl
        uses: superfly/flyctl-actions/setup-flyctl@master

      - name: Deploy to Fly.io
        run: cd v2 && flyctl deploy --remote-only
        env:
          FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
```

### Build Process
1. **Svelte build** produces static files in `v2/web/build/`
2. **Dockerfile** copies static files and builds Go binary
3. **Go binary** embeds static files and serves them
4. **Fly.io** builds and deploys the container

## Branch Protection

Configure branch protection on `main` to require CI to pass:

**GitHub Settings > Branches > Branch protection rules > Add rule:**
- Branch name pattern: `main`
- Require status checks to pass before merging: Yes
- Required status checks:
  - `Go API`
  - `Svelte Web`
- Require branches to be up to date before merging: Yes (recommended)

## Required Secrets

| Secret | Purpose | How to Obtain |
|--------|---------|---------------|
| `FLY_API_TOKEN` | Authenticate with Fly.io | `fly tokens create deploy -x 999999h` |

### Adding Secrets to GitHub
```bash
# Generate a deploy token (long-lived)
fly tokens create deploy -x 999999h

# Add to GitHub repository secrets:
# Settings > Secrets and variables > Actions > New repository secret
# Name: FLY_API_TOKEN
# Value: <token from above>
```

## Workflow Files

```
.github/workflows/
├── CI.yml              # Existing v1 CI (unchanged)
├── ci-v2.yml           # v2 PR checks
├── preview-v2.yml      # v2 preview deployments
└── deploy-v2.yml       # v2 production deployment
```

## Implementation Checklist

- [ ] Create `v2/testdata/seed.sqlite` with test data
- [ ] Create `.github/workflows/ci-v2.yml`
- [ ] Create `.github/workflows/preview-v2.yml`
- [ ] Create `.github/workflows/deploy-v2.yml`
- [ ] Generate Fly.io deploy token: `fly tokens create deploy -x 999999h`
- [ ] Add `FLY_API_TOKEN` to GitHub repository secrets
- [ ] Create `preview` label in GitHub repository
- [ ] Configure branch protection on `main`
- [ ] Test CI by opening a PR with v2 changes
- [ ] Test preview deployment by adding `preview` label to PR
- [ ] Test production deployment by merging PR to main

## Future Enhancements

Not required for initial setup:

- **Database migrations**: Run migrations before deployment
- **Health checks**: Verify deployment succeeded before marking complete
- **Notifications**: Slack/Discord notifications on deploy success/failure
- **Staging environment**: Persistent staging app (separate from PR previews)
