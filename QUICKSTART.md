# Quick Start Guide

## Docker Hub Authentication Issue?

If you're getting an authentication error when running `make start`, you have two options:

### Option 1: Use Simplified Setup (Recommended)

Use the simplified docker-compose that doesn't require building custom images:

```bash
# Use the simplified version
docker-compose -f docker-compose.simple.yml up -d

# Or copy it as the default
cp docker-compose.simple.yml docker-compose.yml
make start
```

This version uses:
- **Pushgateway** instead of a custom Python metrics generator
- **curl container** to push sample metrics periodically
- No custom image builds required

### Option 2: Authenticate with Docker Hub

If you want to use the full setup with the custom metrics generator:

```bash
# Login to Docker Hub (free account)
docker login

# Or if using Podman
podman login docker.io

# Then start normally
make start
```

### Option 3: Build Without Authentication

If you have access issues, you can try:

```bash
# Pull the base image without authentication (may work depending on rate limits)
docker pull python:3.11-slim

# Then start
make start
```

## Recommended: Use Simplified Setup

For most users, the simplified setup is recommended because:
- No authentication needed
- Faster startup (no image building)
- Still provides all the metrics needed for comparison
- Identical functionality for testing recording rules performance

## After Starting

Once the services are running (with either method):

1. **Wait 30-60 seconds** for all services to start
2. **Access Grafana**: http://localhost:3000
   - Username: `admin`
   - Password: `admin`
3. **Open the dashboard**: "Prometheus vs VictoriaMetrics - Recording Rules Performance"
4. **Let it run for 15-30 minutes** to collect meaningful comparison data

## Verify Services

```bash
# Check all services are running
make status
# or
docker-compose ps

# Check Prometheus is scraping
curl http://localhost:9090/api/v1/targets

# Check recording rules are working
curl http://localhost:9090/api/v1/rules
curl http://localhost:8880/api/v1/rules
```

## Troubleshooting

### Services won't start

```bash
# Check logs
make logs

# Or specific service
docker-compose logs -f prometheus
docker-compose logs -f vmalert
```

### No data in Grafana

Wait a bit longer - it takes time to:
1. Start all services
2. Begin scraping metrics
3. Evaluate recording rules
4. Populate time-series data

Give it at least 2-3 minutes before troubleshooting.

### Still having issues?

See the full [README.md](README.md) for detailed troubleshooting steps.
