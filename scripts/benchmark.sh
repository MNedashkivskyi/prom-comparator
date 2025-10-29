#!/bin/bash

# Benchmark script to collect performance metrics
# Usage: ./scripts/benchmark.sh [duration_minutes]

DURATION_MINUTES=${1:-30}
DURATION_SECONDS=$((DURATION_MINUTES * 60))
OUTPUT_DIR="benchmark-results-$(date +%Y%m%d-%H%M%S)"

echo "Running benchmark for $DURATION_MINUTES minutes..."
echo "Results will be saved to: $OUTPUT_DIR"

mkdir -p "$OUTPUT_DIR"

# Function to query Prometheus
query_prom() {
    local query=$1
    curl -s "http://localhost:9090/api/v1/query?query=$query" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "N/A"
}

# Function to query VictoriaMetrics
query_vm() {
    local query=$1
    curl -s "http://localhost:8427/api/v1/query?query=$query" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "N/A"
}

# Start collecting metrics
echo "timestamp,prom_cpu,prom_memory_mb,prom_rule_duration_avg,prom_rule_duration_max,vm_cpu,vmalert_cpu,vm_memory_mb,vmalert_memory_mb,vmalert_rule_duration_avg,vmalert_rule_duration_max" > "$OUTPUT_DIR/metrics.csv"

START_TIME=$(date +%s)
SAMPLE_INTERVAL=30

while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))

    if [ $ELAPSED -ge $DURATION_SECONDS ]; then
        break
    fi

    TIMESTAMP=$(date +%Y-%m-%d\ %H:%M:%S)

    # Prometheus metrics
    PROM_CPU=$(query_prom 'rate(process_cpu_seconds_total{job="prometheus"}[1m])*100')
    PROM_MEM=$(query_prom 'process_resident_memory_bytes{job="prometheus"}/1024/1024')
    PROM_RULE_AVG=$(query_prom 'avg(prometheus_rule_group_duration_seconds)')
    PROM_RULE_MAX=$(query_prom 'max(prometheus_rule_group_duration_seconds)')

    # VictoriaMetrics stack metrics
    VM_CPU=$(query_vm 'rate(process_cpu_seconds_total{job="victoriametrics"}[1m])*100')
    VMALERT_CPU=$(query_vm 'rate(process_cpu_seconds_total{job="vmalert"}[1m])*100')
    VM_MEM=$(query_vm 'process_resident_memory_bytes{job="victoriametrics"}/1024/1024')
    VMALERT_MEM=$(query_vm 'process_resident_memory_bytes{job="vmalert"}/1024/1024')
    VMALERT_RULE_AVG=$(query_vm 'avg(vmalert_iteration_duration_seconds)')
    VMALERT_RULE_MAX=$(query_vm 'max(vmalert_iteration_duration_seconds)')

    echo "$TIMESTAMP,$PROM_CPU,$PROM_MEM,$PROM_RULE_AVG,$PROM_RULE_MAX,$VM_CPU,$VMALERT_CPU,$VM_MEM,$VMALERT_MEM,$VMALERT_RULE_AVG,$VMALERT_RULE_MAX" >> "$OUTPUT_DIR/metrics.csv"

    echo "[$ELAPSED/$DURATION_SECONDS seconds] Collected sample..."

    sleep $SAMPLE_INTERVAL
done

echo ""
echo "Benchmark complete! Generating summary..."

# Generate summary
cat > "$OUTPUT_DIR/summary.txt" << EOF
Benchmark Summary
=================
Duration: $DURATION_MINUTES minutes
Completed: $(date)

Prometheus Performance
----------------------
EOF

# Calculate averages using awk
awk -F',' 'NR>1 {
    prom_cpu_sum+=$2; prom_mem_sum+=$3; prom_rule_avg_sum+=$4; prom_rule_max_sum+=$5;
    vm_cpu_sum+=$6; vmalert_cpu_sum+=$7; vm_mem_sum+=$8; vmalert_mem_sum+=$9;
    vmalert_rule_avg_sum+=$10; vmalert_rule_max_sum+=$11; count++
} END {
    if (count > 0) {
        print "Average CPU: " prom_cpu_sum/count " %"
        print "Average Memory: " prom_mem_sum/count " MB"
        print "Average Rule Duration: " prom_rule_avg_sum/count " seconds"
        print "Max Rule Duration: " prom_rule_max_sum/count " seconds"
        print ""
        print "VictoriaMetrics Stack Performance"
        print "-----------------------------------"
        print "VM Average CPU: " vm_cpu_sum/count " %"
        print "vmalert Average CPU: " vmalert_cpu_sum/count " %"
        print "Total Average CPU: " (vm_cpu_sum+vmalert_cpu_sum)/count " %"
        print "VM Average Memory: " vm_mem_sum/count " MB"
        print "vmalert Average Memory: " vmalert_mem_sum/count " MB"
        print "Total Average Memory: " (vm_mem_sum+vmalert_mem_sum)/count " MB"
        print "Average Rule Duration: " vmalert_rule_avg_sum/count " seconds"
        print "Max Rule Duration: " vmalert_rule_max_sum/count " seconds"
    }
}' "$OUTPUT_DIR/metrics.csv" >> "$OUTPUT_DIR/summary.txt"

cat "$OUTPUT_DIR/summary.txt"

echo ""
echo "Detailed results saved to: $OUTPUT_DIR"
echo "  - metrics.csv: Time-series data"
echo "  - summary.txt: Performance summary"
