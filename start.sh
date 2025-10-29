#!/bin/bash

set -e

echo "=================================================="
echo "Prometheus vs VictoriaMetrics Comparison"
echo "=================================================="
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "Error: Docker is not running. Please start Docker first."
    exit 1
fi

# Check if Docker Compose is available
if ! command -v docker-compose &> /dev/null; then
    echo "Error: docker-compose is not installed."
    exit 1
fi

echo "Starting all services..."
docker-compose up -d

echo ""
echo "Waiting for services to be ready..."
sleep 10

# Check service health
echo ""
echo "Checking service status..."
docker-compose ps

echo ""
echo "=================================================="
echo "Setup Complete!"
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
echo "  vmagent:                http://localhost:8429"
echo "  Metrics Generator:      http://localhost:8080/metrics"
echo "  Node Exporter:          http://localhost:9100/metrics"
echo ""
echo "To view logs:"
echo "  docker-compose logs -f [service-name]"
echo ""
echo "To stop all services:"
echo "  docker-compose down"
echo ""
echo "To stop and remove all data:"
echo "  docker-compose down -v"
echo ""
echo "=================================================="
