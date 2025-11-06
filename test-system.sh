#!/usr/bin/env bash
# Comprehensive System Test Script
set -euo pipefail

echo "========================================="
echo "Texas Gas Lakehouse - System Test"
echo "========================================="
echo ""

NAMESPACE="texas-gas-lakehouse"
PASS=0
FAIL=0

test_service() {
    local name=$1
    local test=$2
    echo -n "Testing $name... "
    if eval "$test" >/dev/null 2>&1; then
        echo "✓ PASS"
        ((PASS++))
    else
        echo "✗ FAIL"
        ((FAIL++))
    fi
}

echo "1. Pod Health Checks"
echo "-------------------"
test_service "PostgreSQL Pod" "kubectl get pod postgres-0 -n $NAMESPACE -o jsonpath='{.status.phase}' | grep Running"
test_service "MinIO Pod" "kubectl get pod minio-0 -n $NAMESPACE -o jsonpath='{.status.phase}' | grep Running"
test_service "Trino Pod" "kubectl get pod trino-0 -n $NAMESPACE -o jsonpath='{.status.phase}' | grep Running"
test_service "Nessie Pod" "kubectl get pod nessie-0 -n $NAMESPACE -o jsonpath='{.status.phase}' | grep Running"
test_service "Airflow Pod" "kubectl get pod airflow-webserver-0 -n $NAMESPACE -o jsonpath='{.status.phase}' | grep Running"
test_service "Grafana Pod" "kubectl get pod -l app=grafana -n $NAMESPACE -o jsonpath='{.items[0].status.phase}' | grep Running"
test_service "Prometheus Pod" "kubectl get pod -l app=prometheus -n $NAMESPACE -o jsonpath='{.items[0].status.phase}' | grep Running"
test_service "dbt Pod" "kubectl get pod -l app=dbt-server -n $NAMESPACE -o jsonpath='{.items[0].status.phase}' | grep Running"
test_service "Dashboard Pod" "kubectl get pod -l app=dashboard -n $NAMESPACE -o jsonpath='{.items[0].status.phase}' | grep Running"
test_service "Postgres Exporter Pod" "kubectl get pod -l app=postgres-exporter -n $NAMESPACE -o jsonpath='{.items[0].status.phase}' | grep Running"

echo ""
echo "2. Data Validation"
echo "------------------"
test_service "Fuel Sales Data" "kubectl exec postgres-0 -n $NAMESPACE -- psql -U texasdbadm -d texas_db -tAc 'SELECT COUNT(*) FROM analytics.fuel_sales' | grep -E '^[1-9][0-9]+$'"
test_service "Store Sales Data" "kubectl exec postgres-0 -n $NAMESPACE -- psql -U texasdbadm -d texas_db -tAc 'SELECT COUNT(*) FROM analytics.store_sales' | grep -E '^[1-9][0-9]+$'"
test_service "Stations Data" "kubectl exec postgres-0 -n $NAMESPACE -- psql -U texasdbadm -d texas_db -tAc 'SELECT COUNT(*) FROM analytics.stations' | grep -E '^[1-9][0-9]*$'"
test_service "dbt Fact Table" "kubectl exec postgres-0 -n $NAMESPACE -- psql -U texasdbadm -d texas_db -tAc 'SELECT COUNT(*) FROM analytics_mart.fct_daily_sales' | grep -E '^[1-9][0-9]+$'"

echo ""
echo "3. Database Objects"
echo "-------------------"
test_service "Analytics Schema" "kubectl exec postgres-0 -n $NAMESPACE -- psql -U texasdbadm -d texas_db -tAc '\dn' | grep analytics"
test_service "Staging Views" "kubectl exec postgres-0 -n $NAMESPACE -- psql -U texasdbadm -d texas_db -tAc '\dv analytics_staging.*' | grep stg_"
test_service "Mart Schema" "kubectl exec postgres-0 -n $NAMESPACE -- psql -U texasdbadm -d texas_db -tAc '\dn' | grep analytics_mart"

echo ""
echo "4. Service Connectivity"
echo "-----------------------"
test_service "Dashboard (localhost:30000)" "curl -sf http://localhost:30000 -o /dev/null"
test_service "PostgreSQL (localhost:30001)" "nc -z localhost 30001"
test_service "MinIO (localhost:30002)" "curl -sf http://localhost:30002/minio/health/live -o /dev/null"
test_service "Nessie (localhost:30003)" "curl -sf http://localhost:30003 -o /dev/null"
test_service "Trino (localhost:30004)" "curl -sf http://localhost:30004/v1/info -o /dev/null"
test_service "Airflow (localhost:30006)" "curl -sf http://localhost:30006/health -o /dev/null"
test_service "Prometheus (localhost:30007)" "curl -sf http://localhost:30007/-/healthy -o /dev/null"
test_service "Grafana (localhost:30008)" "curl -sf http://localhost:30008/api/health -o /dev/null"

echo ""
echo "5. Configuration"
echo "----------------"
test_service "ConfigMaps Exist" "[ \$(kubectl get configmaps -n $NAMESPACE --no-headers | wc -l) -ge 10 ]"
test_service "Secrets Exist" "[ \$(kubectl get secrets -n $NAMESPACE --no-headers | wc -l) -ge 4 ]"
test_service ".env File Exists" "[ -f .env ]"

echo ""
echo "========================================="
echo "Test Results: $PASS passed, $FAIL failed"
echo "========================================="

if [ $FAIL -eq 0 ]; then
    echo "✓ All tests passed!"
    exit 0
else
    echo "✗ Some tests failed. Review issues."
    exit 1
fi
