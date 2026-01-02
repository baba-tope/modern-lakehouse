#!/usr/bin/env bash
set -euo pipefail

# Configure MetalLB IPs from .env file

project_root="$(cd "$(dirname "$0")" && pwd)"
cd "$project_root"

if [[ ! -f .env ]]; then
  echo "[✗] .env file not found" >&2
  exit 1
fi

# Load .env
set -a
source ./.env
set +a

echo "[•] Configuring MetalLB IP addresses from .env..."

# Update metallb-config.yaml
cat > k8s/metallb-config.yaml <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: cagridge-pool
  namespace: metallb-system
spec:
  addresses:
  - ${METALLB_IP_RANGE}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: cagridge-l2
  namespace: metallb-system
spec:
  ipAddressPools:
  - cagridge-pool
EOF

echo "[•] Updating service manifests with LoadBalancer IPs..."

# Update dashboard
yq eval ".metadata.annotations.\"metallb.universe.tf/loadBalancerIPs\" = \"${DASHBOARD_IP}\"" -i k8s/dashboard.yaml 2>/dev/null || \
  sed -i "s|metallb.universe.tf/loadBalancerIPs:.*|metallb.universe.tf/loadBalancerIPs: ${DASHBOARD_IP}|" k8s/dashboard.yaml

# Add the dashboard-api service
yq eval ".metadata.annotations.\"metallb.universe.tf/loadBalancerIPs\" = \"${DASHBOARD_API_IP}\"" -i k8s/dashboard-api.yaml 2>/dev/null || \
  sed -i "s|metallb.universe.tf/loadBalancerIPs:.*|metallb.universe.tf/loadBalancerIPs: ${DASHBOARD_API_IP}|" k8s/dashboard-api.yaml

# Update postgres
yq eval ".metadata.annotations.\"metallb.universe.tf/loadBalancerIPs\" = \"${POSTGRES_IP}\"" -i k8s/postgres.yaml 2>/dev/null || \
  sed -i "s|metallb.universe.tf/loadBalancerIPs:.*|metallb.universe.tf/loadBalancerIPs: ${POSTGRES_IP}|" k8s/postgres.yaml

# Update minio
yq eval ".metadata.annotations.\"metallb.universe.tf/loadBalancerIPs\" = \"${MINIO_IP}\"" -i k8s/minio.yaml 2>/dev/null || \
  sed -i "s|metallb.universe.tf/loadBalancerIPs:.*|metallb.universe.tf/loadBalancerIPs: ${MINIO_IP}|" k8s/minio.yaml

# Update nessie
yq eval ".metadata.annotations.\"metallb.universe.tf/loadBalancerIPs\" = \"${NESSIE_IP}\"" -i k8s/nessie.yaml 2>/dev/null || \
  sed -i "s|metallb.universe.tf/loadBalancerIPs:.*|metallb.universe.tf/loadBalancerIPs: ${NESSIE_IP}|" k8s/nessie.yaml

# Update trino
yq eval ".metadata.annotations.\"metallb.universe.tf/loadBalancerIPs\" = \"${TRINO_IP}\"" -i k8s/trino.yaml 2>/dev/null || \
  sed -i "s|metallb.universe.tf/loadBalancerIPs:.*|metallb.universe.tf/loadBalancerIPs: ${TRINO_IP}|" k8s/trino.yaml

# Update dbt
yq eval ".metadata.annotations.\"metallb.universe.tf/loadBalancerIPs\" = \"${DBT_IP}\"" -i k8s/dbt.yaml 2>/dev/null || \
  sed -i "s|metallb.universe.tf/loadBalancerIPs:.*|metallb.universe.tf/loadBalancerIPs: ${DBT_IP}|" k8s/dbt.yaml

# Update airflow
yq eval ".metadata.annotations.\"metallb.universe.tf/loadBalancerIPs\" = \"${AIRFLOW_IP}\"" -i k8s/airflow.yaml 2>/dev/null || \
  sed -i "s|metallb.universe.tf/loadBalancerIPs:.*|metallb.universe.tf/loadBalancerIPs: ${AIRFLOW_IP}|" k8s/airflow.yaml

# Update prometheus
yq eval ".metadata.annotations.\"metallb.universe.tf/loadBalancerIPs\" = \"${PROMETHEUS_IP}\"" -i k8s/prometheus.yaml 2>/dev/null || \
  sed -i "s|metallb.universe.tf/loadBalancerIPs:.*|metallb.universe.tf/loadBalancerIPs: ${PROMETHEUS_IP}|" k8s/prometheus.yaml

# Update grafana
yq eval ".metadata.annotations.\"metallb.universe.tf/loadBalancerIPs\" = \"${GRAFANA_IP}\"" -i k8s/grafana.yaml 2>/dev/null || \
  sed -i "s|metallb.universe.tf/loadBalancerIPs:.*|metallb.universe.tf/loadBalancerIPs: ${GRAFANA_IP}|" k8s/grafana.yaml

# Update Nginx Ingress Controller (if INGRESS_IP is set)
if [[ -n "${INGRESS_IP:-}" ]]; then
  echo "[•] Updating Nginx Ingress Controller LoadBalancer IP..."
  cat > k8s/ingress-nginx-lb.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: ingress-nginx-controller
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/component: controller
  annotations:
    metallb.universe.tf/loadBalancerIPs: ${INGRESS_IP}
spec:
  type: LoadBalancer
  ports:
  - name: http
    port: 80
    protocol: TCP
    targetPort: http
  - name: https
    port: 443
    protocol: TCP
    targetPort: https
  selector:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/component: controller
EOF
fi

# Update Grafana root URL in secret creation
sed -i "s|GF_SERVER_ROOT_URL=\"http://[0-9.]*:[0-9]*\"|GF_SERVER_ROOT_URL=\"http://${GRAFANA_IP}:30008\"|" create-secrets.sh

echo "[✓] IP configuration complete"
echo ""
echo "Configured IPs:"
echo "  Ingress:     ${INGRESS_IP}:80 (Nginx Ingress Controller)"
echo "  Dashboard:   ${DASHBOARD_IP}:30000"
echo "  PostgreSQL:  ${POSTGRES_IP}:30001"
echo "  MinIO:       ${MINIO_IP}:30002 / :30009"
echo "  Nessie:      ${NESSIE_IP}:30003"
echo "  Trino:       ${TRINO_IP}:30004"
echo "  dbt:         ${DBT_IP}:30005"
echo "  Airflow:     ${AIRFLOW_IP}:30006"
echo "  Prometheus:  ${PROMETHEUS_IP}:30007"
echo "  Grafana:     ${GRAFANA_IP}:30008"
echo "  Dashboard API: ${DASHBOARD_API_IP}:30010"
