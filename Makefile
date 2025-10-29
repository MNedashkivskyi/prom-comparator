.PHONY: help start start-custom start-stress stop stop-stress restart logs clean status reload-prometheus reload-vmalert benchmark

help:
	@echo "Prometheus vs VictoriaMetrics Comparison"
	@echo ""
	@echo "Basic Commands:"
	@echo "  make start              - Start all services (simple setup, no Docker login needed)"
	@echo "  make start-custom       - Start with custom metrics generator (requires Docker login)"
	@echo "  make stop               - Stop all services"
	@echo "  make restart            - Restart all services"
	@echo "  make status             - Show service status"
	@echo "  make clean              - Stop and remove all containers and volumes"
	@echo ""
	@echo "Stress Testing:"
	@echo "  make start-stress       - Start stress test environment (high load)"
	@echo "  make stop-stress        - Stop stress test environment"
	@echo "  make benchmark          - Run 30-minute benchmark (requires stress test running)"
	@echo ""
	@echo "Monitoring:"
	@echo "  make logs               - Show logs from all services"
	@echo "  make logs-prom          - Show Prometheus logs"
	@echo "  make logs-vmalert       - Show vmalert logs"
	@echo "  make logs-vm            - Show VictoriaMetrics logs"
	@echo ""
	@echo "Configuration:"
	@echo "  make reload-prometheus  - Reload Prometheus configuration"
	@echo "  make reload-vmalert     - Reload vmalert configuration"
	@echo ""
	@echo "Quick Access:"
	@echo "  make open-grafana       - Open Grafana in browser"
	@echo "  make open-prometheus    - Open Prometheus in browser"

start:
	@echo "Starting all services (simple setup)..."
	docker-compose up -d
	@echo "Services started! Access Grafana at http://localhost:3000"
	@echo "Note: Using simplified metrics generator (no custom build required)"

start-custom:
	@echo "Starting all services (custom metrics generator)..."
	@echo "Note: This requires Docker Hub authentication"
	docker-compose -f docker-compose.custom.yml up -d
	@echo "Services started! Access Grafana at http://localhost:3000"

start-stress:
	@echo "Starting STRESS TEST environment..."
	@echo "WARNING: This will use significant system resources!"
	./stress-test.sh

stop:
	@echo "Stopping all services..."
	docker-compose stop

stop-stress:
	@echo "Stopping stress test environment..."
	docker-compose -f docker-compose.stress.yml down

restart:
	@echo "Restarting all services..."
	docker-compose restart

logs:
	docker-compose logs -f

logs-prom:
	docker-compose logs -f prometheus

logs-vmalert:
	docker-compose logs -f vmalert

logs-vm:
	docker-compose logs -f victoriametrics

status:
	docker-compose ps

clean:
	@echo "Stopping and removing all containers and volumes..."
	docker-compose down -v
	@echo "Cleanup complete!"

reload-prometheus:
	@echo "Reloading Prometheus configuration..."
	curl -X POST http://localhost:9090/-/reload
	@echo "Prometheus reloaded!"

reload-vmalert:
	@echo "Restarting vmalert to reload configuration..."
	docker-compose restart vmalert
	@echo "vmalert reloaded!"

open-grafana:
	@echo "Opening Grafana..."
	@which xdg-open > /dev/null && xdg-open http://localhost:3000 || open http://localhost:3000

open-prometheus:
	@echo "Opening Prometheus..."
	@which xdg-open > /dev/null && xdg-open http://localhost:9090 || open http://localhost:9090

benchmark:
	@echo "Running 30-minute benchmark..."
	@echo "Make sure stress test is running first (make start-stress)"
	./scripts/benchmark.sh 30
