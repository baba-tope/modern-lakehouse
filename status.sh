#!/usr/bin/env bash
set -euo pipefail

# Cagridge Data Lakehouse - Status (bash)

project_root="$(cd "$(dirname "$0")" && pwd)"
cd "$project_root"

if [[ -f .env ]]; then set -a; source ./.env; set +a; fi
NAMESPACE="${NAMESPACE}"

echo "====================================="
echo "  Cagridge Data Lakehouse Status"
echo "====================================="

echo "[•] Pods:"
kubectl get pods -n "$NAMESPACE"

echo

echo "[•] Services:"
kubectl get svc -n "$NAMESPACE"

echo

echo "[•] Persistent Volumes & Claims:"
kubectl get pv
kubectl get pvc -n "$NAMESPACE"

echo

echo "[•] Endpoints (from .env):"
cat <<EOF
Dashboard:          http://${DASHBOARD_IP:-172.18.0.200}:30000
PostgreSQL:         ${POSTGRES_IP:-172.18.0.201}:30001
MinIO API:          http://${MINIO_IP:-172.18.0.202}:30002
MinIO Console:      http://${MINIO_IP:-172.18.0.202}:30009
Nessie:             http://${NESSIE_IP:-172.18.0.203}:30003
Trino:              http://${TRINO_IP:-172.18.0.204}:30004
dbt:                http://${DBT_IP:-172.18.0.205}:30005
Airflow:            http://${AIRFLOW_IP:-172.18.0.206}:30006
Prometheus:         http://${PROMETHEUS_IP:-172.18.0.207}:30007
Grafana:            http://${GRAFANA_IP:-172.18.0.208}:30008
Dashboard API:      http://${DASHBOARD_API_IP:-172.18.0.210}:30010

Note: Port-forward alternative: ./port-forward.sh (for localhost access)
EOF
