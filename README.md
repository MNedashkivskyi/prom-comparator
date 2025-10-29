# Prometheus vs VictoriaMetrics Recording Rules Performance Comparison

This project provides a comprehensive performance comparison between:
- **Prometheus**: Executing recording rules locally on its TSDB
- **VictoriaMetrics + vmalert**: Executing the same recording rules remotely via VictoriaMetrics

## Architecture

### Stack A: Prometheus (Local Evaluation)
```
┌─────────────────────────────────────────────────┐
│  Prometheus                                      │
│  ├─ Scrapes metrics from exporters              │
│  ├─ Evaluates recording rules locally (TSDB)    │
│  └─ Remote writes to VictoriaMetrics (sink)     │
└─────────────────────────────────────────────────┘
```

### Stack B: VictoriaMetrics (Remote Evaluation)
```
┌─────────────────────────────────────────────────┐
│  vmagent → scrapes metrics                       │
│      ↓                                           │
│  VictoriaMetrics → stores metrics (short TTL)    │
│      ↓                                           │
│  vmalert → queries VM and evaluates rules        │
└─────────────────────────────────────────────────┘
```

## What's Being Compared?

The comparison focuses on:

1. **Rule Evaluation Duration**: How long it takes to execute recording rules
2. **CPU Usage**: Resource consumption during rule evaluation
3. **Memory Usage**: RAM requirements for each approach
4. **Query Performance**: Query latency (p50, p95, p99)
5. **Throughput**: Number of rule evaluations per second
6. **Accuracy**: Ensuring both systems produce identical results

## Components

### Monitoring Stacks

- **Prometheus** (port 9090): Local rule evaluation
- **VictoriaMetrics** (port 8427): Storage for vmalert
- **VictoriaMetrics Prom Sink** (port 8428): Receives Prometheus remote writes
- **vmagent** (port 8429): Scraper for VictoriaMetrics stack
- **vmalert** (port 8880): Remote rule evaluation

### Data Sources

- **node-exporter** (port 9100): System metrics (CPU, memory, disk, network)
- **metrics-generator** (port 8080): Custom metrics generator for testing

### Visualization

- **Grafana** (port 3000): Performance comparison dashboards
  - Default credentials: `admin` / `admin`

## Getting Started

### Prerequisites

- Docker
- Docker Compose
- 4GB+ RAM recommended
- 2+ CPU cores recommended

### Quick Start

1. Clone the repository:
```bash
git clone <repository-url>
cd prom-comparator
```

2. Start all services:
```bash
# Simple setup (no Docker login required) - RECOMMENDED
./start.sh
# or
make start

# Alternative: Custom metrics generator (requires Docker Hub login)
make start-custom
```

3. Wait for all services to start (30-60 seconds):
```bash
docker-compose ps
```

4. Access Grafana:
```bash
open http://localhost:3000
```
- Username: `admin`
- Password: `admin`

5. Open the "Prometheus vs VictoriaMetrics - Recording Rules Performance" dashboard

**Note:** The default setup uses a simplified metrics generator that doesn't require building custom Docker images. See [QUICKSTART.md](QUICKSTART.md) if you encounter Docker authentication issues.

### Viewing Individual Components

- **Prometheus UI**: http://localhost:9090
- **VictoriaMetrics**: http://localhost:8427
- **VictoriaMetrics Prom Sink**: http://localhost:8428
- **vmagent**: http://localhost:8429
- **vmalert**: http://localhost:8880
- **Metrics Generator**: http://localhost:8080/metrics
- **Node Exporter**: http://localhost:9100/metrics
- **Grafana**: http://localhost:3000

## Recording Rules

Both stacks evaluate identical recording rules located in:
- `configs/prometheus/rules/recording_rules.yml`
- `configs/vmalert/rules/recording_rules.yml`

### Rule Categories

1. **Simple Aggregations**
   - CPU utilization per instance
   - Memory utilization per instance
   - Filesystem utilization

2. **Complex Aggregations**
   - HTTP request rates by status
   - Error ratios
   - Multi-level aggregations

3. **Expensive Operations**
   - Histogram quantiles (p50, p95, p99)
   - Cross-metric joins
   - Multi-dimensional aggregations

## Grafana Dashboard

The main dashboard provides side-by-side comparison:

### Performance Metrics
- **Rule Evaluation Duration**: Time to evaluate rules
- **CPU Usage**: Resource consumption
- **Memory Usage**: RAM utilization
- **Query Duration**: p50, p95, p99 latencies
- **Evaluation Rate**: Rules evaluated per second

### Output Verification
- Recording rule outputs shown side-by-side
- Ensures both systems produce identical results

## Running Tests

### Load Testing

Increase the load on the metrics generator by scaling it:
```bash
docker-compose up -d --scale metrics-generator=3
```

### Different Retention Periods

Modify retention in `docker-compose.yml`:

For Prometheus:
```yaml
command:
  - '--storage.tsdb.retention.time=1h'  # Change this
```

For VictoriaMetrics:
```yaml
command:
  - '--retentionPeriod=1h'  # Change this
```

Then restart:
```bash
docker-compose restart prometheus victoriametrics
```

### Stress Testing

To stress test the rule evaluation, add more complex recording rules to:
- `configs/prometheus/rules/recording_rules.yml`
- `configs/vmalert/rules/recording_rules.yml`

Then reload:
```bash
# Reload Prometheus
curl -X POST http://localhost:9090/-/reload

# Reload vmalert
docker-compose restart vmalert
```

## Interpreting Results

### Expected Behavior

**Prometheus Advantages:**
- Lower latency for rule evaluation (no network overhead)
- Simpler architecture
- Direct access to TSDB

**VictoriaMetrics Advantages:**
- Lower memory usage (no local TSDB in vmalert)
- Faster query execution on large datasets
- Better compression and storage efficiency
- Horizontal scalability

### Key Metrics to Watch

1. **Rule Evaluation Duration**: Compare `prometheus_rule_group_duration_seconds` vs `vmalert_iteration_duration_seconds`
2. **CPU Usage**: Sum of Prometheus CPU vs sum of (vmalert + VictoriaMetrics) CPU
3. **Memory Usage**: Prometheus memory vs (vmalert + VictoriaMetrics) memory
4. **Query Percentiles**: Response time distribution

## Troubleshooting

### Services not starting

Check logs:
```bash
docker-compose logs -f <service-name>
```

### No data in Grafana

1. Verify datasources are configured:
   - Go to Configuration → Data Sources
   - Test each datasource

2. Check if metrics are being collected:
```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Check VictoriaMetrics
curl http://localhost:8427/api/v1/labels
```

### Recording rules not working

Check rule evaluation:
```bash
# Prometheus rules status
curl http://localhost:9090/api/v1/rules

# vmalert rules status
curl http://localhost:8880/api/v1/rules
```

### High resource usage

Reduce scrape frequency in configs:
- `configs/prometheus/prometheus.yml`
- `configs/vmagent/vmagent.yml`

Change `scrape_interval` from `15s` to `30s` or `60s`.

## Cleanup

Stop and remove all containers:
```bash
docker-compose down
```

Remove volumes (deletes all data):
```bash
docker-compose down -v
```

## Project Structure

```
prom-comparator/
├── docker-compose.yml              # Main orchestration file
├── configs/
│   ├── prometheus/
│   │   ├── prometheus.yml          # Prometheus configuration
│   │   └── rules/
│   │       └── recording_rules.yml # Prometheus recording rules
│   ├── vmagent/
│   │   └── vmagent.yml             # vmagent scrape config
│   ├── vmalert/
│   │   └── rules/
│   │       └── recording_rules.yml # vmalert recording rules (identical)
│   └── grafana/
│       ├── provisioning/
│       │   ├── datasources/        # Auto-configured datasources
│       │   └── dashboards/         # Dashboard provisioning
│       └── dashboards/
│           └── performance-comparison.json
├── metrics-generator/
│   ├── Dockerfile
│   ├── requirements.txt
│   └── app.py                      # Custom metrics generator
└── README.md
```

## Customization

### Adding More Recording Rules

1. Edit both rule files:
   - `configs/prometheus/rules/recording_rules.yml`
   - `configs/vmalert/rules/recording_rules.yml`

2. Reload configurations:
```bash
curl -X POST http://localhost:9090/-/reload
docker-compose restart vmalert
```

### Changing Scrape Targets

Edit scrape configs:
- Prometheus: `configs/prometheus/prometheus.yml`
- vmagent: `configs/vmagent/vmagent.yml`

### Custom Dashboards

Add JSON dashboards to `configs/grafana/dashboards/` and they'll be auto-loaded.

## Performance Tuning

### Prometheus Optimization

In `docker-compose.yml`:
```yaml
prometheus:
  command:
    - '--storage.tsdb.min-block-duration=2h'
    - '--storage.tsdb.max-block-duration=2h'
    - '--query.max-concurrency=20'
    - '--query.timeout=2m'
```

### VictoriaMetrics Optimization

```yaml
victoriametrics:
  command:
    - '--search.maxConcurrentRequests=20'
    - '--search.maxQueueDuration=30s'
    - '--memory.allowedPercent=80'
```

### vmalert Optimization

```yaml
vmalert:
  command:
    - '--evaluationInterval=15s'
    - '--datasource.maxIdleConnections=100'
    - '--datasource.queryStep=15s'
```

## Contributing

Feel free to:
- Add more recording rules
- Enhance the metrics generator
- Improve dashboards
- Add more test scenarios

## License

See LICENSE file.

## References

- [Prometheus Recording Rules](https://prometheus.io/docs/prometheus/latest/configuration/recording_rules/)
- [VictoriaMetrics](https://docs.victoriametrics.com/)
- [vmalert](https://docs.victoriametrics.com/vmalert.html)
- [vmagent](https://docs.victoriametrics.com/vmagent.html)
