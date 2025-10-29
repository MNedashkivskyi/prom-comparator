#!/bin/bash

set -e

echo "=================================================="
echo "Prometheus vs VictoriaMetrics STRESS TEST"
echo "=================================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running. Please start Docker first.${NC}"
    exit 1
fi

echo -e "${YELLOW}⚠️  WARNING: This stress test will:${NC}"
echo "  - Use significant CPU and memory resources"
echo "  - Generate high cardinality metrics (thousands of time series)"
echo "  - Evaluate 50+ complex recording rules every 10 seconds"
echo "  - Scrape metrics every 5 seconds"
echo "  - Run 3 concurrent metrics generators"
echo ""
echo -e "${YELLOW}Recommended system requirements:${NC}"
echo "  - 8GB+ RAM"
echo "  - 4+ CPU cores"
echo "  - 10GB+ free disk space"
echo ""
read -p "Do you want to continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Stress test cancelled."
    exit 0
fi

echo ""
echo "Starting stress test environment..."
docker-compose -f docker-compose.stress.yml up -d

echo ""
echo "Waiting for services to start..."
sleep 15

echo ""
echo "=================================================="
echo "Stress Test Environment Started!"
echo "=================================================="
echo ""
echo "Access the following services:"
echo ""
echo "  Grafana Dashboard:      http://localhost:3000"
echo "    (username: admin, password: admin)"
echo ""
echo "  Prometheus UI:          http://localhost:9090"
echo "  VictoriaMetrics:        http://localhost:8427"
echo "  vmalert:                http://localhost:8880"
echo "  Pushgateway:            http://localhost:9091"
echo ""
echo -e "${GREEN}Metrics Generators Status:${NC}"
docker-compose -f docker-compose.stress.yml ps | grep stress-generator
echo ""
echo "=================================================="
echo "Stress Test Monitoring"
echo "=================================================="
echo ""
echo "Monitor resource usage:"
echo "  docker stats"
echo ""
echo "View logs:"
echo "  docker-compose -f docker-compose.stress.yml logs -f [service]"
echo ""
echo "Check recording rules:"
echo "  curl http://localhost:9090/api/v1/rules | jq"
echo "  curl http://localhost:8880/api/v1/rules | jq"
echo ""
echo "To stop the stress test:"
echo "  docker-compose -f docker-compose.stress.yml down"
echo ""
echo -e "${YELLOW}Tip: Let it run for at least 30 minutes to see meaningful results!${NC}"
echo "=================================================="
