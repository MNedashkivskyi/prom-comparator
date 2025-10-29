# Testing Guide

This document describes various testing scenarios and how to interpret the results.

## Basic Testing

### 1. Verify All Services Are Running

```bash
make status
# or
docker-compose ps
```

All services should show status as "Up".

### 2. Check Metrics Collection

**Prometheus:**
```bash
# Check Prometheus is scraping
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'

# Check recording rules are working
curl -s http://localhost:9090/api/v1/rules | jq '.data.groups[].rules[] | select(.type=="recording") | .name'
```

**VictoriaMetrics:**
```bash
# Check vmalert rules
curl -s http://localhost:8880/api/v1/rules | jq '.data.groups[].rules[] | select(.type=="recording") | .name'

# Check VictoriaMetrics has data
curl -s http://localhost:8427/api/v1/labels
```

### 3. Verify Dashboard Data

Open Grafana at http://localhost:3000 and check:
- All panels show data
- Both Prometheus and VictoriaMetrics panels are populated
- No errors in query inspector (click panel title → Inspect → Query)

## Performance Testing Scenarios

### Scenario 1: Baseline Performance (Default)

**Setup:** Default configuration, 15s evaluation interval

**What to observe:**
- Rule evaluation duration difference
- CPU and memory usage patterns
- Query latency percentiles

**Expected results:**
- Prometheus: Lower latency, higher memory
- VictoriaMetrics: Slightly higher latency, lower memory

### Scenario 2: High-Frequency Evaluation

**Setup:**
```yaml
# In docker-compose.yml, change for both Prometheus and vmalert:
evaluation_interval: 5s
```

Restart services:
```bash
docker-compose up -d
```

**What to observe:**
- Increased CPU usage
- More frequent rule evaluations
- Potential differences in performance under stress

### Scenario 3: Heavy Recording Rules

Add more complex rules to `configs/prometheus/rules/recording_rules.yml` and `configs/vmalert/rules/recording_rules.yml`:

```yaml
- record: expensive:network_io:total
  expr: |
    sum by (instance) (
      rate(node_network_receive_bytes_total[5m])
      + rate(node_network_transmit_bytes_total[5m])
    )
    / 1024 / 1024  # Convert to MB

- record: expensive:disk_io_percentage:total
  expr: |
    sum by (instance) (
      rate(node_disk_read_bytes_total[5m])
      + rate(node_disk_written_bytes_total[5m])
    )
    /
    (
      node_filesystem_size_bytes
      - node_filesystem_avail_bytes
    )
    * 100
```

Reload:
```bash
make reload-prometheus
make reload-vmalert
```

**What to observe:**
- Impact on evaluation duration
- Resource usage increase
- Query performance under load

### Scenario 4: Large Dataset Simulation

Scale up the metrics generator:
```bash
docker-compose up -d --scale metrics-generator=5
```

**What to observe:**
- Performance with more series
- Memory growth patterns
- Query performance degradation (if any)

### Scenario 5: Long Lookback Windows

Modify recording rules to use longer time windows:
```yaml
- record: instance:node_cpu_utilization:ratio_30m
  expr: |
    (1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[30m]))) * 100
```

**What to observe:**
- Evaluation time increase
- Impact on Prometheus vs VictoriaMetrics
- Query complexity handling

## Benchmarking

### CPU Usage Comparison

```bash
# Get average CPU usage over 5 minutes
# Prometheus
curl -s "http://localhost:9090/api/v1/query?query=avg_over_time(rate(process_cpu_seconds_total{job=\"prometheus\"}[5m])[5m:15s])*100" | jq '.data.result[0].value[1]'

# vmalert + VictoriaMetrics
curl -s "http://localhost:8427/api/v1/query?query=avg_over_time((rate(process_cpu_seconds_total{job=\"vmalert\"}[5m])+rate(process_cpu_seconds_total{job=\"victoriametrics\"}[5m]))[5m:15s])*100" | jq '.data.result[0].value[1]'
```

### Memory Usage Comparison

```bash
# Prometheus
curl -s "http://localhost:9090/api/v1/query?query=process_resident_memory_bytes{job=\"prometheus\"}" | jq '.data.result[0].value[1] | tonumber / 1024 / 1024'

# vmalert + VictoriaMetrics (sum)
curl -s "http://localhost:8427/api/v1/query?query=sum(process_resident_memory_bytes{job=~\"vmalert|victoriametrics\"})" | jq '.data.result[0].value[1] | tonumber / 1024 / 1024'
```

### Rule Evaluation Duration

```bash
# Prometheus average evaluation duration
curl -s "http://localhost:9090/api/v1/query?query=avg(prometheus_rule_group_duration_seconds)" | jq '.data.result[0].value[1]'

# vmalert average evaluation duration
curl -s "http://localhost:8427/api/v1/query?query=avg(vmalert_iteration_duration_seconds)" | jq '.data.result[0].value[1]'
```

### Query Performance Test

Create a test script:
```bash
#!/bin/bash
# test-query-performance.sh

QUERY="sum(rate(http_requests_total[5m])) by (job)"

echo "Testing Prometheus..."
time curl -s "http://localhost:9090/api/v1/query?query=$(echo $QUERY | jq -sRr @uri)" > /dev/null

echo "Testing VictoriaMetrics..."
time curl -s "http://localhost:8427/api/v1/query?query=$(echo $QUERY | jq -sRr @uri)" > /dev/null
```

Run it multiple times:
```bash
chmod +x test-query-performance.sh
for i in {1..10}; do ./test-query-performance.sh; done
```

## Stress Testing

### Maximum Rule Complexity

Create a very complex recording rule:
```yaml
- record: stress:complex_calculation
  expr: |
    sum by (instance) (
      histogram_quantile(0.99,
        sum by (instance, le) (
          rate(http_request_duration_seconds_bucket[5m])
        )
      )
    )
    /
    avg by (instance) (
      rate(http_request_duration_seconds_sum[5m])
      /
      rate(http_request_duration_seconds_count[5m])
    )
```

### High Cardinality Metrics

Modify `metrics-generator/app.py` to generate more labels:
```python
# Add more dimensions
endpoints = [f'/api/endpoint-{i}' for i in range(100)]
services = [f'service-{i}' for i in range(50)]
```

Rebuild and restart:
```bash
docker-compose up -d --build metrics-generator
```

## Troubleshooting Tests

### Test 1: Metrics Not Appearing

```bash
# Check if metrics generator is producing metrics
curl http://localhost:8080/metrics | grep http_requests_total

# Check if Prometheus is scraping
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job=="metrics-generator")'

# Check if vmagent is scraping
curl http://localhost:8429/api/v1/targets
```

### Test 2: Recording Rules Not Evaluating

```bash
# Check Prometheus rule groups
curl http://localhost:9090/api/v1/rules | jq '.data.groups[] | {name: .name, interval: .interval, lastEvaluation: .lastEvaluation}'

# Check vmalert rule groups
curl http://localhost:8880/api/v1/rules | jq '.data.groups[] | {name: .name, interval: .interval, lastEvaluation: .lastEvaluation}'
```

### Test 3: High Memory Usage

```bash
# Check Prometheus heap profile
curl http://localhost:9090/debug/pprof/heap > prom-heap.prof

# Check number of time series
curl -s http://localhost:9090/api/v1/query?query=prometheus_tsdb_head_series | jq '.data.result[0].value[1]'
curl -s http://localhost:8427/api/v1/query?query=vm_cache_entries{type="storage/hour_metric_ids"} | jq '.data.result[0].value[1]'
```

## Expected Test Results

### Small Dataset (< 10k series)
- Prometheus: ~50-100ms rule evaluation
- VictoriaMetrics: ~80-150ms rule evaluation
- Both should use < 500MB memory

### Medium Dataset (10k-100k series)
- Prometheus: ~200-500ms rule evaluation
- VictoriaMetrics: ~150-400ms rule evaluation
- Prometheus: 1-2GB memory
- VictoriaMetrics: 800MB-1.5GB memory

### Large Dataset (> 100k series)
- VictoriaMetrics typically performs better
- Prometheus memory usage grows faster
- Query latency favors VictoriaMetrics

## Automated Testing

Create a comprehensive test script:
```bash
#!/bin/bash
# run-all-tests.sh

set -e

echo "Running comprehensive tests..."

# Wait for services
sleep 30

# Test 1: Service health
echo "Test 1: Checking service health..."
docker-compose ps | grep -q "Up" || exit 1

# Test 2: Metrics collection
echo "Test 2: Verifying metrics collection..."
curl -sf http://localhost:9090/api/v1/targets | jq -e '.data.activeTargets | length > 0' || exit 1

# Test 3: Recording rules
echo "Test 3: Verifying recording rules..."
curl -sf http://localhost:9090/api/v1/rules | jq -e '.data.groups | length > 0' || exit 1

# Test 4: Grafana datasources
echo "Test 4: Checking Grafana datasources..."
curl -sf http://admin:admin@localhost:3000/api/datasources | jq -e 'length >= 3' || exit 1

echo "All tests passed!"
```

Run:
```bash
chmod +x run-all-tests.sh
./run-all-tests.sh
```

## Continuous Monitoring

Set up a monitoring dashboard in Grafana to continuously track:
1. Rule evaluation duration trends
2. Resource usage patterns
3. Error rates
4. Data freshness

Export results periodically for analysis:
```bash
# Export metrics to CSV
curl -s "http://localhost:9090/api/v1/query?query=prometheus_rule_group_duration_seconds" | \
  jq -r '.data.result[] | [.metric.rule_group, .value[1]] | @csv' > prometheus-perf.csv

curl -s "http://localhost:8427/api/v1/query?query=vmalert_iteration_duration_seconds" | \
  jq -r '.data.result[] | [.metric.group, .value[1]] | @csv' > vmalert-perf.csv
```
