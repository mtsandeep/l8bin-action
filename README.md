# LiteBin | L8Bin GitHub Action

Deploy your app to LiteBin directly from GitHub Actions — no Docker registry needed.

## Quick Start

Add this to your repo's `.github/workflows/deploy.yml`:

```yaml
name: Deploy to LiteBin

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: mtsandeep/l8bin-action@v1
        with:
          server: ${{ secrets.L8B_SERVER }}
          token: ${{ secrets.L8B_TOKEN }}
          project_id: myapp
          port: '3000'
```

### Required Secrets

| Secret | Description |
|--------|-------------|
| `L8B_SERVER` | Your LiteBin orchestrator URL — the dashboard/API subdomain (e.g. `https://l8bin.example.com`) |
| `L8B_TOKEN` | Deploy token from the LiteBin dashboard (per-project) |

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `server` | Yes | | Orchestrator dashboard URL (e.g. `https://l8bin.example.com`) |
| `token` | Yes | | Deploy token |
| `project_id` | Yes | | Project ID (used as subdomain) |
| `port` | No | `3000` | Internal port your app listens on |
| `path` | No | `.` | Path to the project directory |
| `dockerfile` | No | | Custom Dockerfile path (auto-detected if omitted) |
| `cmd` | No | | Custom command to run in the container |
| `memory` | No | | Memory limit in MB |
| `cpu` | No | | CPU limit (0.0 - 1.0) |
| `node_id` | No | | Target node ID |

## Outputs

| Output | Description |
|--------|-------------|
| `url` | URL of the deployed application |

## How It Works

1. **Detects build method** — if a `Dockerfile` exists, uses `docker build`. Otherwise, installs [Railpack](https://railpack.io) and auto-detects your framework.
2. **Saves the image** as a tar file.
3. **Uploads** the tar directly to your LiteBin server (no container registry needed).
4. **Deploys** the image and returns the URL.

## Examples

### Custom Dockerfile

```yaml
- uses: mtsandeep/l8bin-action@v1
  with:
    server: ${{ secrets.L8B_SERVER }}
    token: ${{ secrets.L8B_TOKEN }}
    project_id: myapp
    dockerfile: docker/Dockerfile.prod
```

### With resource limits

```yaml
- uses: mtsandeep/l8bin-action@v1
  with:
    server: ${{ secrets.L8B_SERVER }}
    token: ${{ secrets.L8B_TOKEN }}
    project_id: myapp
    port: '8080'
    memory: '512'
    cpu: '0.5'
```

### Deploy to a specific node

```yaml
- uses: mtsandeep/l8bin-action@v1
  with:
    server: ${{ secrets.L8B_SERVER }}
    token: ${{ secrets.L8B_TOKEN }}
    project_id: myapp
    node_id: node-2
```

### Monorepo / subdirectory

```yaml
- uses: mtsandeep/l8bin-action@v1
  with:
    server: ${{ secrets.L8B_SERVER }}
    token: ${{ secrets.L8B_TOKEN }}
    project_id: myapp
    path: apps/frontend
```

Use `path` when your app lives in a subdirectory of the repo. The action will build from that directory instead of the repo root.

## Getting a Deploy Token

1. Log in to your LiteBin dashboard
2. Go to your project settings
3. Create a deploy token
4. Add it as a GitHub secret in your repo (`Settings > Secrets > Actions`)
