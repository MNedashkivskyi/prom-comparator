# Pull Request: Add Comprehensive Stress Testing for Recording Rules Comparison

## Overview

This PR adds a complete stress testing environment to thoroughly benchmark Prometheus vs VictoriaMetrics recording rule performance under heavy load with high cardinality metrics.

## What's New

### 🔥 Stress Test Environment
- **docker-compose.stress.yml**: High-load configuration with 3 concurrent metrics generators
- **10,000+ time series**: High cardinality across regions, versions, endpoints, methods, etc.
- **Aggressive intervals**: 5s scraping, 10s rule evaluation (vs 15s/15s normal)
- **Resource optimized**: Proper memory limits and concurrency settings

### 📊 Complex Recording Rules (50+ rules)
Identical rules for both Prometheus and vmalert to ensure fair comparison:
- Simple aggregations (CPU, memory)
- Multi-dimensional aggregations (high cardinality)
- Histogram quantiles: p50, p75, p90, p95, p99, p999
- Multi-level rules (rules depending on other rules)
- Heavy computations (weighted averages, standard deviations)
- Long lookback windows (30m, 1h)
- Subqueries with moving averages and peak detection

### 🎯 High-Cardinality Metrics
Three concurrent generators producing diverse metrics:
- HTTP requests with regions, versions, methods, status codes
- Request duration histograms
- Database queries across tables and operations
- gRPC service metrics
- Kafka messages with partitions
- System metrics (connections, queues, cache ratios)

### 🤖 Automation Scripts
- **stress-test.sh**: Interactive launcher with system requirement checks
- **scripts/benchmark.sh**: Automated performance data collection
  - Configurable duration (default 30 minutes)
  - Samples every 30 seconds
  - Generates CSV data and summary reports
  - Compares CPU, memory, rule evaluation times

### 📖 Documentation
- **STRESS_TEST.md**: Comprehensive guide including:
  - System requirements (8GB+ RAM, 4+ CPU cores recommended)
  - Setup and monitoring instructions
  - Multiple stress test scenarios
  - Performance tuning tips
  - Troubleshooting guide
  - Expected results analysis

### 🔧 Makefile Commands
- `make start-stress`: Launch stress test environment
- `make stop-stress`: Stop stress test
- `make benchmark`: Run 30-minute automated benchmark

## Files Added

```
docker-compose.stress.yml                      # Stress test Docker setup
stress-test.sh                                 # Interactive launcher
scripts/benchmark.sh                           # Automated benchmarking

configs/prometheus-stress/
  prometheus.yml                               # Stress config
  rules/stress_recording_rules.yml             # 50+ complex rules

configs/vmalert-stress/
  rules/stress_recording_rules.yml             # Identical rules

configs/vmagent/
  vmagent-stress.yml                           # Stress scrape config

STRESS_TEST.md                                 # Complete documentation
```

## What Gets Tested

✅ **Rule evaluation duration** - Prometheus local TSDB vs vmalert remote queries
✅ **CPU efficiency** - Single Prometheus vs VM+vmalert combined
✅ **Memory usage** - TSDB overhead vs distributed architecture
✅ **Query performance** - Local vs remote query latency (p95, p99)
✅ **High cardinality handling** - Performance with 10,000+ series
✅ **Long-term stability** - Performance patterns over time
✅ **Scalability** - Behavior under increasing load

## Usage

### Quick Start
```bash
# Start stress test
make start-stress

# Run 30-minute benchmark
make benchmark

# Stop stress test
make stop-stress
```

### Custom Duration
```bash
# 1 hour benchmark
./scripts/benchmark.sh 60

# 2 hours
./scripts/benchmark.sh 120
```

## System Requirements

- **Minimum**: 8GB RAM, 4 CPU cores, 10GB disk
- **Recommended**: 16GB RAM, 8+ CPU cores, 20GB disk

## Expected Results

### Prometheus (Local TSDB)
✅ Lower latency (no network overhead)
✅ Simpler architecture
❌ Higher memory usage
❌ Slower with very high cardinality

### VictoriaMetrics (Remote Evaluation)
✅ Lower memory (vmalert doesn't store data)
✅ Better high cardinality handling
✅ More horizontally scalable
❌ Slightly higher latency (network queries)

## Monitoring

Once running, access:
- **Grafana**: http://localhost:3000
- **Prometheus**: http://localhost:9090
- **VictoriaMetrics**: http://localhost:8427
- **vmalert**: http://localhost:8880

Monitor with:
```bash
docker stats
make logs
```

## Testing Checklist

- [x] Stress test environment starts successfully
- [x] All 3 metrics generators produce data
- [x] Prometheus evaluates all 50+ rules
- [x] vmalert evaluates all 50+ rules
- [x] Grafana dashboard shows comparison data
- [x] Benchmark script collects metrics
- [x] Documentation is complete

## Breaking Changes

None - this is purely additive. The normal setup continues to work as before.

## Related

This builds on the base comparison setup added in the initial PR.

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
