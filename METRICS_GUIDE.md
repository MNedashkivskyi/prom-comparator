# Stress Test Metrics Guide

## Understanding Recording Rule Performance Metrics

### Quick Answer: What's Faster?

Compare these two metrics side-by-side:

1. **Prometheus**: `prometheus_rule_group_duration_seconds`
2. **vmalert**: `vmalert_iteration_duration_seconds`

**Lower is better!** ⏱️

---

## Key Metrics Breakdown

### 🔵 Prometheus Metrics

#### 1. Rule Evaluation Duration
```promql
# Average time per rule
rate(prometheus_rule_evaluation_duration_seconds_sum[5m]) /
rate(prometheus_rule_evaluation_duration_seconds_count[5m])
```

**What it means**: Average time to evaluate a single rule on local TSDB
**Includes**: Query execution, computation
**Excludes**: Network latency (data is local)

#### 2. Rule Group Duration (⭐ PRIMARY METRIC)
```promql
prometheus_rule_group_duration_seconds
```

**What it means**: Total time to evaluate ALL rules in a group
**Typical values**:
- Normal load: 0.1-0.5 seconds
- High load: 0.5-2.0 seconds
- Extreme load: 2.0+ seconds

#### 3. Evaluations Rate
```promql
rate(prometheus_rule_evaluations_total[5m])
```

**What it means**: How many rule evaluations per second
**Higher is better** (shows system is keeping up)

#### 4. Failures
```promql
rate(prometheus_rule_evaluation_failures_total[5m])
```

**What it means**: Failed rule evaluations per second
**Should be**: 0 (any failures indicate problems)

---

### 🟢 vmalert Metrics

#### 1. Iteration Duration (⭐ PRIMARY METRIC)
```promql
vmalert_iteration_duration_seconds
```

**What it means**: Time for complete rule group evaluation cycle
**Includes**:
- Query to VictoriaMetrics (network)
- Rule computation
- Write results back (network)

**Typical values**:
- Normal load: 0.2-0.8 seconds
- High load: 0.8-3.0 seconds
- Extreme load: 3.0+ seconds

#### 2. Iterations Rate
```promql
rate(vmalert_iteration_total[5m])
```

**What it means**: How many iterations per second
**Higher is better**

#### 3. Execution Errors
```promql
rate(vmalert_execution_errors_total[5m])
```

**What it means**: Failed executions per second
**Should be**: 0

---

## 📊 How to Compare: Step-by-Step

### Step 1: Check Rule Evaluation Time

**Open Grafana**: http://localhost:3000

**Look at these panels:**

1. **"Prometheus - Rule Evaluation Duration"** (left side)
   - Check: `Avg Rule Eval Duration` line
   - Note the value (e.g., 0.234s)

2. **"vmalert - Rule Evaluation Duration"** (right side)
   - Check: `Avg Iteration Duration` line
   - Note the value (e.g., 0.298s)

**Example Interpretation:**
```
Prometheus: 0.234s per group
vmalert:    0.298s per group
Result:     Prometheus is 27% faster (local TSDB advantage)
```

### Step 2: Check CPU Efficiency

**Look at CPU panels:**

1. **"Prometheus - CPU Usage"**
   - Single process CPU usage
   - Example: 45% CPU

2. **"VictoriaMetrics Stack - CPU Usage"**
   - Sum of vmalert + VictoriaMetrics CPU
   - Example: vmalert 15% + VM 25% = 40% total

**Example Interpretation:**
```
Prometheus:           45% CPU
VM Stack (total):     40% CPU
Result:               VM stack is 11% more CPU efficient
```

### Step 3: Check Memory Usage

**Look at memory panels:**

1. **"Prometheus - Memory Usage"**
   - Includes local TSDB storage
   - Example: 2.1 GB

2. **"VictoriaMetrics Stack - Memory Usage"**
   - vmalert + VictoriaMetrics combined
   - Example: vmalert 0.3 GB + VM 1.2 GB = 1.5 GB

**Example Interpretation:**
```
Prometheus:           2.1 GB
VM Stack (total):     1.5 GB
Result:               VM stack uses 29% less memory
```

### Step 4: Check Query Performance

**Navigate to "Query Duration Percentiles" panels**

1. **Prometheus - Query Duration Percentiles**
   - p99 Query Duration (slowest 1% of queries)
   - Example: p99 = 0.45s

2. **VictoriaMetrics - Query Duration Percentiles**
   - p99 Query Duration
   - Example: p99 = 0.38s

**Example Interpretation:**
```
Prometheus p99:       0.45s
VictoriaMetrics p99:  0.38s
Result:               VM handles complex queries 16% faster
```

---

## 🎯 Real-World Interpretation

### Scenario 1: Prometheus Wins
```
Prometheus group duration:     0.15s
vmalert iteration duration:    0.35s

Prometheus CPU:                35%
VM Stack CPU:                  42%

Prometheus Memory:             1.8 GB
VM Stack Memory:               2.1 GB
```

**Verdict**: ✅ **Use Prometheus** if:
- You have a single-node setup
- Low to medium cardinality
- Simplicity is important
- < 5 million active series

### Scenario 2: VictoriaMetrics Wins
```
Prometheus group duration:     1.25s
vmalert iteration duration:    0.85s

Prometheus CPU:                78%
VM Stack CPU:                  55%

Prometheus Memory:             4.2 GB
VM Stack Memory:               2.8 GB
```

**Verdict**: ✅ **Use VictoriaMetrics** if:
- High cardinality (millions of series)
- Need horizontal scaling
- Distributed architecture
- Long retention requirements

### Scenario 3: Mixed Results (Common!)
```
Prometheus group duration:     0.25s  ← Faster
vmalert iteration duration:    0.35s

Prometheus CPU:                65%
VM Stack CPU:                  45%    ← More efficient

Prometheus Memory:             3.5 GB
VM Stack Memory:               2.2 GB ← Less memory
```

**Verdict**: ⚖️ **Trade-offs**:
- Prometheus: Faster rule evaluation (local TSDB)
- VictoriaMetrics: Better resource efficiency, more scalable

**Choose based on priorities**:
- Need speed → Prometheus
- Need efficiency/scale → VictoriaMetrics

---

## 📈 Command Line Queries

### Quick comparison queries:

```bash
# Prometheus average rule group duration
curl -s 'http://localhost:9090/api/v1/query?query=avg(prometheus_rule_group_duration_seconds)' | jq -r '.data.result[0].value[1]'

# vmalert average iteration duration
curl -s 'http://localhost:8427/api/v1/query?query=avg(vmalert_iteration_duration_seconds)' | jq -r '.data.result[0].value[1]'

# Compare CPU usage
echo "Prometheus CPU:"
curl -s 'http://localhost:9090/api/v1/query?query=rate(process_cpu_seconds_total{job="prometheus"}[5m])*100' | jq -r '.data.result[0].value[1]'

echo "VM Stack CPU:"
curl -s 'http://localhost:8427/api/v1/query?query=sum(rate(process_cpu_seconds_total{job=~"vmalert|victoriametrics"}[5m]))*100' | jq -r '.data.result[0].value[1]'

# Compare memory
echo "Prometheus Memory (MB):"
curl -s 'http://localhost:9090/api/v1/query?query=process_resident_memory_bytes{job="prometheus"}/1024/1024' | jq -r '.data.result[0].value[1]'

echo "VM Stack Memory (MB):"
curl -s 'http://localhost:8427/api/v1/query?query=sum(process_resident_memory_bytes{job=~"vmalert|victoriametrics"})/1024/1024' | jq -r '.data.result[0].value[1]'
```

---

## 🚨 Red Flags to Watch For

### ❌ Bad Signs (Either System)

1. **Evaluation failures**
```promql
# Should be 0
prometheus_rule_evaluation_failures_total
vmalert_execution_errors_total
```

2. **Increasing latency over time**
- Rule duration keeps growing
- Indicates memory pressure or disk I/O issues

3. **High CPU with low throughput**
- CPU > 80% but rules taking longer
- System is thrashing

4. **OOM (Out of Memory)**
```bash
# Check logs
docker logs prometheus | grep -i "out of memory"
docker logs vmalert | grep -i "out of memory"
```

---

## 📊 What "Winning" Looks Like

### For Speed (Lower Latency)
```
✅ Rule group/iteration duration: < 0.5s
✅ No evaluation failures
✅ p95 query latency: < 1s
✅ p99 query latency: < 2s
```

### For Efficiency (Better Resource Usage)
```
✅ CPU usage: < 60% under load
✅ Memory stable (not growing)
✅ Query throughput: High (many rules/sec)
✅ Can handle 10,000+ series easily
```

---

## 🎓 Advanced Analysis

### Check Rule-by-Rule Performance

**Prometheus:**
```promql
# Slowest rules
topk(10, prometheus_rule_group_duration_seconds)
```

**vmalert:**
```promql
# Slowest rule groups
topk(10, vmalert_iteration_duration_seconds)
```

### Check Time Series Cardinality

```bash
# Prometheus active series
curl -s 'http://localhost:9090/api/v1/query?query=prometheus_tsdb_head_series' | jq -r '.data.result[0].value[1]'

# VictoriaMetrics active series
curl -s 'http://localhost:8427/api/v1/query?query=vm_cache_entries{type="storage/hour_metric_ids"}' | jq -r '.data.result[0].value[1]'
```

### Monitor Over Time

Run the benchmark script:
```bash
# Collect data for 1 hour
./scripts/benchmark.sh 60

# Review results
cat benchmark-results-*/summary.txt
```

---

## 💡 Pro Tips

1. **Let it run for at least 30 minutes** before drawing conclusions
   - First 5-10 minutes: Warm-up period
   - After 30 minutes: Stable performance patterns

2. **Watch trends, not snapshots**
   - One spike doesn't mean much
   - Consistent patterns matter

3. **Compare apples to apples**
   - Same recording rules in both
   - Same scrape intervals
   - Same evaluation intervals

4. **Your mileage may vary**
   - Results depend on your specific recording rules
   - High cardinality favors VictoriaMetrics
   - Simple queries favor Prometheus

5. **Test with YOUR data**
   - This stress test is generic
   - Real decision needs your actual metrics and queries

---

## 📝 Summary Checklist

After running the stress test, you should be able to answer:

- [ ] Which system has lower rule evaluation duration?
- [ ] Which system uses less CPU?
- [ ] Which system uses less memory?
- [ ] Which system has better query latency (p95, p99)?
- [ ] Do either system have failures/errors?
- [ ] How do they perform over time (1+ hours)?
- [ ] Which better fits my scaling needs?

---

## 🤝 Still Confused?

### Quick Decision Tree:

**Choose Prometheus if:**
- You prioritize **lowest latency** for rule evaluation
- You have **simple, single-node** deployment
- You have **< 10 million series**
- You want **simplicity**

**Choose VictoriaMetrics if:**
- You have **high cardinality** (millions of series)
- You need **horizontal scaling**
- You prioritize **resource efficiency**
- You want **distributed architecture**

**The "right" answer depends on YOUR specific requirements!**
