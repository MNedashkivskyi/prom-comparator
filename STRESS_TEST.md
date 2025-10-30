## Stress Testing Guide

This guide explains how to run comprehensive stress tests to compare Prometheus and VictoriaMetrics recording rule performance under heavy load.

## What's Different in Stress Test Mode?

### Normal Setup vs Stress Test

| Aspect | Normal Setup | Stress Test (High Cardinality) |
|--------|-------------|-------------|
| Scrape Interval | 15s | 3s |
| Evaluation Interval | 15s | 10s |
| Metrics Generators | 1 simple | 3 high-cardinality (scalable) |
| Recording Rules | 15 basic rules | 120 complex rules |
| Time Series | ~1,000 | ~15,000+ (target) |
| Label Dimensions | Basic | Extended (tenant, datacenter, environment, cluster, team) |
| Memory Usage | <500MB | 2-4GB |
| CPU Usage | Low | High |

### Stress Test Features

1. **Very High Cardinality Metrics**
   - **Extended label dimensions**: tenant (3 values), datacenter (4 values), environment (2 values), cluster (5 values), team (4 values)
   - **HTTP requests** with extensive label combinations across 15+ endpoints
   - **Database queries** across multiple DBs (postgres, mysql), 8+ tables, 4+ operations
   - **Kafka messages** across 4+ topics, 8-16 partitions, 3+ consumer groups
   - **gRPC services**: 5+ services with 12+ methods and status codes
   - **Connection pools** and cache metrics with shard variations
   - **Queue metrics** with multiple priorities and worker pods
   - Each generator creates unique metrics when scaled using hostname

2. **Complex Recording Rules (120 total)**
   - Multi-dimensional aggregations across all label combinations
   - Expensive histogram quantiles (p50, p75, p90, p95, p99, p999)
   - Multi-level rules (rules depending on other rules)
   - Heavy computations (weighted averages, standard deviations)
   - Long lookback windows (30m, 1h)
   - Subqueries with moving averages
   - Cross-service correlation rules

3. **Very Aggressive Scraping**
   - **3-second scrape intervals** (vs 15s normal)
   - **1-second metric push intervals** from generators
   - 10-second rule evaluation
   - Multiple concurrent generators (scalable from 3 to 20+)
   - Continuous high-frequency metric updates
   - Target: ~15,000 active time series

## System Requirements

### Minimum Requirements
- 8GB RAM
- 4 CPU cores
- 10GB free disk space

### Recommended for Best Results
- 16GB+ RAM
- 8+ CPU cores
- 20GB+ free disk space
- SSD storage

## Running Stress Tests

### Quick Start

```bash
# Start stress test
./stress-test.sh

# Or using docker-compose directly
docker-compose -f docker-compose.stress.yml up -d
```

### Step-by-Step

1. **Prepare your system**
```bash
# Close unnecessary applications
# Ensure Docker has enough resources allocated
# Docker Desktop: Settings → Resources → increase CPU/Memory
```

2. **Start the stress test**
```bash
./stress-test.sh
```

3. **Monitor the systems**
```bash
# Watch resource usage in real-time
docker stats

# Or use the monitoring dashboard
open http://localhost:3000
```

4. **Run automated benchmarks** (optional)
```bash
# Collect metrics for 30 minutes (default)
./scripts/benchmark.sh

# Or specify duration
./scripts/benchmark.sh 60  # 60 minutes
```

5. **Let it run**
   - Minimum: 30 minutes for meaningful data
   - Recommended: 1-2 hours for comprehensive results
   - Production simulation: 4-24 hours

## Monitoring Stress Tests

### Grafana Dashboard

Access http://localhost:3000 and look for:
- **Rule Evaluation Duration**: Should show clear differences under load
- **CPU Usage**: Compare total CPU (Prometheus vs VM+vmalert)
- **Memory Usage**: Watch memory growth patterns
- **Query Latency**: p95 and p99 percentiles

### Command Line Monitoring

```bash
# Watch Docker stats
docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Check Prometheus rule status
curl -s http://localhost:9090/api/v1/rules | jq '.data.groups[] | {name: .name, lastEvaluation: .lastEvaluation, evaluationTime: .evaluationTime}'

# Check vmalert rule status
curl -s http://localhost:8880/api/v1/rules | jq '.data.groups[] | {name: .name, lastEvaluation: .lastEvaluation, evaluationTime: .evaluationTime}'

# Check number of active time series
curl -s 'http://localhost:9090/api/v1/query?query=prometheus_tsdb_head_series' | jq '.data.result[0].value[1]'
curl -s 'http://localhost:8427/api/v1/query?query=vm_cache_entries{type="storage/hour_metric_ids"}' | jq '.data.result[0].value[1]'
```

### Real-Time Metrics

```bash
# Prometheus performance
watch -n 5 'curl -s "http://localhost:9090/api/v1/query?query=prometheus_rule_group_duration_seconds" | jq -r ".data.result[] | .metric.rule_group + \": \" + .value[1] + \"s\""'

# vmalert performance
watch -n 5 'curl -s "http://localhost:8427/api/v1/query?query=vmalert_iteration_duration_seconds" | jq -r ".data.result[] | .metric.group + \": \" + .value[1] + \"s\""'
```

## Benchmark Results Analysis

After running `./scripts/benchmark.sh`, check the results:

```bash
ls -la benchmark-results-*/
cat benchmark-results-*/summary.txt
```

### Key Metrics to Compare

1. **Rule Evaluation Duration**
   - Lower is better
   - Compare average and maximum
   - Look for consistency vs spikes

2. **CPU Usage**
   - Prometheus: Single process
   - VictoriaMetrics: Sum of VM + vmalert
   - Calculate cost efficiency

3. **Memory Usage**
   - Prometheus: Includes local TSDB
   - VictoriaMetrics: Separate storage and query
   - Watch for memory growth over time

4. **Query Performance**
   - Check p95 and p99 latencies
   - Test complex queries
   - Measure under load

## Stress Test Scenarios

### Scenario 1: High Cardinality (Default)

Already configured with 3 generators producing diverse metrics.

**Expected behavior:**
- Prometheus: Higher memory usage
- VictoriaMetrics: Better handling of cardinality

### Scenario 2: Extreme Cardinality

The default stress test now generates ~15,000 time series with high cardinality labels. To increase even further, scale up the generators:

```bash
# 9 total generators (~30,000-40,000 time series)
docker-compose -f docker-compose.stress.yml up -d --scale stress-generator-1=3 --scale stress-generator-2=3 --scale stress-generator-3=3

# 21 total generators (~70,000-90,000 time series)
docker-compose -f docker-compose.stress.yml up -d --scale stress-generator-1=7 --scale stress-generator-2=7 --scale stress-generator-3=7
```

Each generator instance creates unique metrics using its hostname, ensuring true cardinality multiplication.

### Scenario 3: More Complex Rules

Add additional recording rules to the rule files:
- `configs/prometheus-stress/rules/stress_recording_rules.yml`
- `configs/vmalert-stress/rules/stress_recording_rules.yml`

Example expensive rule:
```yaml
- record: endpoint:http_p99_per_region_per_version
  expr: |
    histogram_quantile(0.99,
      sum by (endpoint, region, version, method, le) (
        rate(http_request_duration_seconds_bucket[5m])
      )
    )
    /
    sum by (endpoint, region, version) (
      rate(http_requests_total[5m])
    )
```

Reload:
```bash
curl -X POST http://localhost:9090/-/reload
docker-compose -f docker-compose.stress.yml restart vmalert
```

### Scenario 4: Faster Evaluation

Edit `docker-compose.stress.yml` to evaluate more frequently:

```yaml
prometheus:
  command:
    - '--evaluation_interval=5s'

vmalert:
  command:
    - '--evaluationInterval=5s'
```

### Scenario 5: Long-Running Stress Test

Run for 24 hours to observe:
- Memory leak patterns
- Performance degradation over time
- Storage efficiency
- Compaction behavior

```bash
./scripts/benchmark.sh 1440  # 24 hours
```

## Performance Tuning

### Prometheus Optimization

Add to Prometheus command in `docker-compose.stress.yml`:

```yaml
- '--query.max-samples=50000000'
- '--query.timeout=5m'
- '--storage.tsdb.min-block-duration=2h'
- '--storage.tsdb.max-block-duration=2h'
- '--storage.tsdb.wal-compression'
```

### VictoriaMetrics Optimization

Add to VictoriaMetrics command:

```yaml
- '--search.maxQueryDuration=5m'
- '--search.maxConcurrentRequests=50'
- '--memory.allowedPercent=80'
- '--search.latencyOffset=30s'
```

### vmalert Optimization

Add to vmalert command:

```yaml
- '--datasource.maxIdleConnections=100'
- '--remoteWrite.maxQueueSize=10000'
- '--rule.maxResolveDuration=5m'
```

## Troubleshooting Stress Tests

### Services Crashing / OOM

Increase Docker resources:

```bash
# Docker Desktop: Settings → Resources
# Increase memory to 8GB or more
# Increase CPUs to 4 or more
```

Or reduce load:

```bash
# Stop one or more generators
docker-compose -f docker-compose.stress.yml stop stress-generator-3

# Reduce scrape frequency
# Edit configs/prometheus-stress/prometheus.yml and configs/vmagent/vmagent-stress.yml
# Change scrape_interval from 3s to 5s, 10s, or 15s
```

### Rules Not Evaluating

Check for errors:

```bash
# Prometheus
curl http://localhost:9090/api/v1/rules | jq '.data.groups[] | select(.lastError != null)'

# vmalert
curl http://localhost:8880/api/v1/rules | jq '.data.groups[] | select(.lastError != null)'

# Check logs
docker-compose -f docker-compose.stress.yml logs prometheus | grep -i error
docker-compose -f docker-compose.stress.yml logs vmalert | grep -i error
```

### High Query Latency

Some queries are intentionally expensive. Monitor with:

```bash
# Slow queries in Prometheus
curl 'http://localhost:9090/api/v1/query?query=topk(10,prometheus_engine_query_duration_seconds{quantile="0.99"})'

# Check query queue
curl 'http://localhost:9090/api/v1/query?query=prometheus_engine_queries'
```

### Disk Space Issues

Monitor disk usage:

```bash
docker system df
du -sh /var/lib/docker/volumes/prom-comparator_*

# Clean up if needed (WARNING: deletes all data)
docker-compose -f docker-compose.stress.yml down -v
```

## Cleanup

### Stop Stress Test

```bash
# Stop services
docker-compose -f docker-compose.stress.yml down

# Remove volumes (deletes all metrics data)
docker-compose -f docker-compose.stress.yml down -v

# Clean up benchmark results
rm -rf benchmark-results-*/
```

### Resource Cleanup

```bash
# Remove unused Docker resources
docker system prune -a --volumes

# Check freed space
docker system df
```

## Expected Results

### Typical Performance Characteristics

**Prometheus (Local TSDB)**
- ✅ Lower latency for rule evaluation (no network hop)
- ✅ Simpler architecture
- ❌ Higher memory usage (stores everything locally)
- ❌ Slower with very high cardinality
- ❌ Limited horizontal scalability

**VictoriaMetrics (Remote Evaluation)**
- ✅ Lower memory usage (vmalert doesn't store data)
- ✅ Better with high cardinality
- ✅ More horizontally scalable
- ✅ Better compression
- ❌ Slightly higher latency (network queries)
- ❌ More complex architecture

### When to Use Each

**Use Prometheus local rules when:**
- Single node deployment
- Low to medium cardinality
- Simplicity is priority
- < 10 million active series

**Use vmalert when:**
- Distributed deployment
- High cardinality (millions of series)
- Need horizontal scaling
- Long retention requirements
- Multiple Prometheus instances

## Advanced Testing

### Custom Metrics

Create your own metrics generator:

```bash
# Push custom metrics to pushgateway
cat <<EOF | curl --data-binary @- http://localhost:9091/metrics/job/custom-test/instance/test-1
# TYPE custom_metric counter
custom_metric{label1="value1",label2="value2"} 123
EOF
```

### Load Testing Tools

Use existing load testing tools:

```bash
# Install Prometheus load generator
go install github.com/prometheus/test-infra/prombench/cmd/prometheus-load-generator@latest

# Run load generator
prometheus-load-generator \
  --target=http://localhost:9091 \
  --workers=10 \
  --series=10000 \
  --interval=5s
```

### Custom Benchmark Scripts

Create your own benchmarks by querying the APIs:

```python
#!/usr/bin/env python3
import requests
import time
import statistics

def benchmark_query(url, query, iterations=100):
    latencies = []
    for _ in range(iterations):
        start = time.time()
        requests.get(f"{url}/api/v1/query", params={"query": query})
        latency = time.time() - start
        latencies.append(latency)

    return {
        "p50": statistics.median(latencies),
        "p95": statistics.quantiles(latencies, n=20)[18],
        "p99": statistics.quantiles(latencies, n=100)[98],
        "avg": statistics.mean(latencies)
    }

# Test Prometheus
prom_results = benchmark_query(
    "http://localhost:9090",
    "sum(rate(http_requests_total[5m]))"
)

# Test VictoriaMetrics
vm_results = benchmark_query(
    "http://localhost:8427",
    "sum(rate(http_requests_total[5m]))"
)

print("Prometheus:", prom_results)
print("VictoriaMetrics:", vm_results)
```

## Contributing Stress Tests

To add new stress test scenarios:

1. Create new rule files in `configs/*/rules/`
2. Add generators to `docker-compose.stress.yml`
3. Document the scenario in this file
4. Submit a PR with results

## References

- [Prometheus Performance Tips](https://prometheus.io/docs/practices/performance/)
- [VictoriaMetrics Performance](https://docs.victoriametrics.com/Single-server-VictoriaMetrics.html#capacity-planning)
- [vmalert Best Practices](https://docs.victoriametrics.com/vmalert.html#quickstart)
