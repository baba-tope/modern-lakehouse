#!/usr/bin/env bash
set -euo pipefail

# Cagridge Data Lakehouse - Deploy all services (bash)

project_root="$(cd "$(dirname "$0")" && pwd)"
cd "$project_root"

if ! command_v() { command -v "$1" >/dev/null 2>&1; }; then :; fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "[✗] kubectl not found in PATH" >&2
  exit 1
fi

# Load env to get NAMESPACE
if [[ -f .env ]]; then
  set -a; source ./.env; set +a
fi
NAMESPACE="${NAMESPACE:-texas-gas-lakehouse}"

echo "====================================="
echo "  Cagridge Data Lakehouse Deployment"
echo "====================================="

echo "[1/8] Configuring IPs and dashboard from .env..."
./configure-ips.sh
./generate-dashboard.sh

echo "[2/8] Creating namespace and secrets from .env..."
kubectl apply -f k8s/namespace.yaml
./create-secrets.sh

echo "[3/8] Installing MetalLB (if not already installed)..."
if ! kubectl get namespace metallb-system >/dev/null 2>&1; then
  echo "Installing MetalLB v0.13.12..."
  kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml
  echo "Waiting for MetalLB to be ready..."
  kubectl wait --namespace metallb-system \
    --for=condition=ready pod \
    --selector=app=metallb \
    --timeout=90s
else
  echo "MetalLB already installed, skipping..."
fi

echo "[4/8] Configuring MetalLB IP pool..."
kubectl apply -f k8s/metallb-config.yaml
sleep 3

echo "[5/8] Deploying core services..."
kubectl apply -f k8s/postgres.yaml
kubectl apply -f k8s/minio.yaml
kubectl apply -f k8s/nessie.yaml
kubectl apply -f k8s/trino.yaml
kubectl apply -f k8s/dbt.yaml
kubectl apply -f k8s/airflow.yaml
kubectl apply -f k8s/prometheus.yaml
kubectl apply -f k8s/grafana.yaml

echo "[6/8] Creating dashboard ConfigMap and deploying dashboard..."
kubectl create configmap dashboard-html --from-file=dashboard/index.html -n "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f k8s/dashboard.yaml

echo "[7/8] Waiting for PostgreSQL to become Ready..."
kubectl wait --for=condition=Ready pod -l app=postgres -n "$NAMESPACE" --timeout=10m || true

echo "[7.5/8] Initializing PostgreSQL database schema..."
# Wait a bit more for PostgreSQL to fully start accepting connections
sleep 10
if kubectl get pod -n "$NAMESPACE" -l app=postgres -o name | grep -q postgres; then
  POD_NAME=$(kubectl get pod -n "$NAMESPACE" -l app=postgres -o jsonpath='{.items[0].metadata.name}')
  echo "Copying init.sql to PostgreSQL pod..."
  # Use cat to pipe the content instead of kubectl cp (more reliable on Windows)
  cat sql/init.sql | kubectl exec -i -n "$NAMESPACE" "$POD_NAME" -- sh -c 'cat > /tmp/init.sql'
  echo "Executing init.sql..."
  kubectl exec -n "$NAMESPACE" "$POD_NAME" -- psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /tmp/init.sql
  echo "Database initialized successfully"
else
  echo "Warning: PostgreSQL pod not found, skipping database initialization"
fi

echo "[8/8] Waiting for remaining pods to become Ready (10 min timeout)..."
# Best-effort wait; continue if timeout
kubectl wait --for=condition=Ready pods --all -n "$NAMESPACE" --timeout=10m || true

echo "[8/8] Current pod status:"
kubectl get pods -n "$NAMESPACE"

echo "[8/8] Service endpoints (MetalLB LoadBalancer IPs):"
cat <<EOF
Dashboard:          http://${DASHBOARD_IP}:30000
PostgreSQL:         ${POSTGRES_IP}:30001
MinIO API:          http://${MINIO_IP}:30002
MinIO Console:      http://${MINIO_IP}:30009
Nessie:             http://${NESSIE_IP}:30003/api/v1
Trino:              http://${TRINO_IP}:30004
dbt:                http://${DBT_IP}:30005
Airflow:            http://${AIRFLOW_IP}:30006
Prometheus:         http://${PROMETHEUS_IP}:30007
Grafana:            http://${GRAFANA_IP}:30008

Note: IPs configured from .env file (METALLB_IP_RANGE).
      Add them to /etc/hosts for friendly names (optional).
EOF

echo "[✓] Deployment complete"
