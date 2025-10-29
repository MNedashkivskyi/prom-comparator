#!/usr/bin/env python3
"""
Metrics Generator for Prometheus vs VictoriaMetrics Comparison
Generates various types of metrics to test recording rule performance
"""

import random
import time
from prometheus_client import Counter, Histogram, Gauge, start_http_server
import threading

# Define metrics
http_requests_total = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

http_request_duration_seconds = Histogram(
    'http_request_duration_seconds',
    'HTTP request latency',
    ['method', 'endpoint'],
    buckets=(0.001, 0.005, 0.01, 0.025, 0.05, 0.075, 0.1, 0.25, 0.5, 0.75, 1.0, 2.5, 5.0, 7.5, 10.0)
)

active_connections = Gauge(
    'active_connections',
    'Number of active connections',
    ['service']
)

queue_size = Gauge(
    'queue_size',
    'Current queue size',
    ['queue_name']
)

processing_time_seconds = Histogram(
    'processing_time_seconds',
    'Processing time',
    ['worker', 'task_type'],
    buckets=(0.1, 0.25, 0.5, 1.0, 2.0, 5.0, 10.0, 30.0, 60.0)
)

data_processed_bytes = Counter(
    'data_processed_bytes_total',
    'Total bytes processed',
    ['processor']
)

error_count = Counter(
    'error_count_total',
    'Total errors',
    ['error_type', 'service']
)

cache_hit_ratio = Gauge(
    'cache_hit_ratio',
    'Cache hit ratio',
    ['cache_name']
)

# HTTP endpoint simulation
endpoints = ['/api/users', '/api/posts', '/api/comments', '/api/likes', '/api/search']
methods = ['GET', 'POST', 'PUT', 'DELETE']
statuses = ['200', '201', '204', '400', '404', '500', '503']

# Workers and services
workers = ['worker-1', 'worker-2', 'worker-3', 'worker-4']
services = ['api', 'database', 'cache', 'queue']
processors = ['video-processor', 'image-processor', 'text-processor']
task_types = ['encode', 'decode', 'transform', 'validate']


def generate_http_metrics():
    """Continuously generate HTTP request metrics"""
    while True:
        endpoint = random.choice(endpoints)
        method = random.choice(methods)

        # Weighted status codes (more success than errors)
        status = random.choices(
            statuses,
            weights=[50, 20, 10, 5, 5, 3, 2],
            k=1
        )[0]

        # Simulate request
        duration = random.uniform(0.001, 2.0)
        if status.startswith('5'):
            duration = random.uniform(5.0, 10.0)  # Errors are slower

        http_requests_total.labels(method=method, endpoint=endpoint, status=status).inc()
        http_request_duration_seconds.labels(method=method, endpoint=endpoint).observe(duration)

        time.sleep(random.uniform(0.01, 0.1))


def generate_system_metrics():
    """Continuously generate system-level metrics"""
    while True:
        # Active connections fluctuate
        for service in services:
            connections = random.randint(10, 1000)
            active_connections.labels(service=service).set(connections)

        # Queue sizes vary
        queue_names = ['job-queue', 'event-queue', 'dead-letter-queue']
        for queue in queue_names:
            size = random.randint(0, 500)
            queue_size.labels(queue_name=queue).set(size)

        # Cache hit ratios
        cache_names = ['redis-cache', 'memcached', 'local-cache']
        for cache in cache_names:
            ratio = random.uniform(0.7, 0.99)
            cache_hit_ratio.labels(cache_name=cache).set(ratio)

        time.sleep(1)


def generate_processing_metrics():
    """Continuously generate processing metrics"""
    while True:
        worker = random.choice(workers)
        task = random.choice(task_types)
        processor = random.choice(processors)

        # Processing time
        proc_time = random.uniform(0.1, 30.0)
        processing_time_seconds.labels(worker=worker, task_type=task).observe(proc_time)

        # Data processed
        bytes_processed = random.randint(1024, 1024 * 1024 * 100)  # 1KB to 100MB
        data_processed_bytes.labels(processor=processor).inc(bytes_processed)

        # Occasional errors
        if random.random() < 0.05:  # 5% error rate
            error_types = ['timeout', 'validation', 'network', 'internal']
            error_type = random.choice(error_types)
            service = random.choice(services)
            error_count.labels(error_type=error_type, service=service).inc()

        time.sleep(random.uniform(0.1, 0.5))


def main():
    """Start the metrics generator"""
    print("Starting metrics generator on port 8080...")

    # Start Prometheus HTTP server
    start_http_server(8080)

    # Start metric generators in separate threads
    threads = [
        threading.Thread(target=generate_http_metrics, daemon=True),
        threading.Thread(target=generate_system_metrics, daemon=True),
        threading.Thread(target=generate_processing_metrics, daemon=True),
    ]

    for thread in threads:
        thread.start()

    print("Metrics generator is running. Metrics available at http://localhost:8080/metrics")

    # Keep the main thread alive
    while True:
        time.sleep(1)


if __name__ == '__main__':
    main()
