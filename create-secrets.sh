#!/usr/bin/env bash
set -euo pipefail

# Cagridge Data Lakehouse - Create Kubernetes secrets from .env (bash)

project_root="$(cd "$(dirname "$0")" && pwd)"
cd "$project_root"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "[✗] kubectl not found in PATH" >&2
  exit 1
fi

if [[ ! -f .env ]]; then
  echo "[✗] .env file not found at $project_root/.env" >&2
  exit 1
fi

# Load .env safely
set -a
# shellcheck disable=SC1091
source ./.env
set +a

NAMESPACE="${NAMESPACE:-texas-gas-lakehouse}"

echo "[•] Ensuring namespace '$NAMESPACE' exists..."
kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 || kubectl apply -f k8s/namespace.yaml

echo "[•] Creating PostgreSQL secret..."
kubectl create secret generic postgres-secret \
  --from-literal=POSTGRES_USER="$POSTGRES_USER" \
  --from-literal=POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
  --from-literal=POSTGRES_DB="$POSTGRES_DB" \
  --from-literal=DATA_SOURCE_NAME="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres-service:5432/${POSTGRES_DB}?sslmode=disable" \
  -n "$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "[•] Creating MinIO secret..."
kubectl create secret generic minio-secret \
  --from-literal=MINIO_ROOT_USER="$MINIO_ROOT_USER" \
  --from-literal=MINIO_ROOT_PASSWORD="$MINIO_ROOT_PASSWORD" \
  -n "$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "[•] Creating Airflow secret..."
airflow_conn="postgresql+psycopg2://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres-service:5432/${POSTGRES_DB}"
# The Fernet/secret keys must stay stable across runs: regenerating them
# invalidates every stored encrypted connection. Generate once and persist to
# .env so re-running this script reuses the same keys.
if [[ -z "${AIRFLOW_FERNET_KEY:-}" ]]; then
  AIRFLOW_FERNET_KEY="$(openssl rand -base64 32)"
  printf '\nAIRFLOW_FERNET_KEY=%s\n' "$AIRFLOW_FERNET_KEY" >> .env
  echo "[•] Generated AIRFLOW_FERNET_KEY and saved it to .env"
fi
if [[ -z "${AIRFLOW_SECRET_KEY:-}" ]]; then
  AIRFLOW_SECRET_KEY="$(openssl rand -base64 32)"
  printf 'AIRFLOW_SECRET_KEY=%s\n' "$AIRFLOW_SECRET_KEY" >> .env
  echo "[•] Generated AIRFLOW_SECRET_KEY and saved it to .env"
fi
# Use provided credentials or defaults
AIRFLOW_USERNAME="${AIRFLOW_USERNAME:-admin}"
AIRFLOW_PASSWORD="${AIRFLOW_PASSWORD:-admin}"
AIRFLOW_FIRSTNAME="${AIRFLOW_FIRSTNAME:-Admin}"
AIRFLOW_LASTNAME="${AIRFLOW_LASTNAME:-User}"
AIRFLOW_EMAIL="${AIRFLOW_EMAIL:-admin@example.com}"
kubectl create secret generic airflow-secret \
  --from-literal=AIRFLOW__CORE__SQL_ALCHEMY_CONN="$airflow_conn" \
  --from-literal=AIRFLOW__CORE__FERNET_KEY="$AIRFLOW_FERNET_KEY" \
  --from-literal=AIRFLOW__WEBSERVER__SECRET_KEY="$AIRFLOW_SECRET_KEY" \
  --from-literal=AIRFLOW_USERNAME="$AIRFLOW_USERNAME" \
  --from-literal=AIRFLOW_PASSWORD="$AIRFLOW_PASSWORD" \
  --from-literal=AIRFLOW_FIRSTNAME="$AIRFLOW_FIRSTNAME" \
  --from-literal=AIRFLOW_LASTNAME="$AIRFLOW_LASTNAME" \
  --from-literal=AIRFLOW_EMAIL="$AIRFLOW_EMAIL" \
  -n "$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "[•] Creating Grafana secret..."
kubectl create secret generic grafana-secret \
  --from-literal=GF_SECURITY_ADMIN_USER="$GF_SECURITY_ADMIN_USER" \
  --from-literal=GF_SECURITY_ADMIN_PASSWORD="$GF_SECURITY_ADMIN_PASSWORD" \
  --from-literal=GF_INSTALL_PLUGINS="$GF_INSTALL_PLUGINS" \
  --from-literal=GF_SERVER_ROOT_URL="http://${GRAFANA_IP}:30008" \
  --from-literal=GF_ANALYTICS_REPORTING_ENABLED="$GF_ANALYTICS_REPORTING_ENABLED" \
  --from-literal=GF_ANALYTICS_CHECK_FOR_UPDATES="$GF_ANALYTICS_CHECK_FOR_UPDATES" \
  -n "$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

# Trino catalog config (as files)
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

cat >"$workdir/iceberg.properties" <<EOF
connector.name=iceberg
iceberg.catalog.type=nessie
iceberg.nessie-catalog.uri=http://nessie-service:19120/api/v1
iceberg.nessie-catalog.ref=main
iceberg.nessie-catalog.default-warehouse-dir=s3://lakehouse/warehouse
fs.native-s3.enabled=true
s3.endpoint=http://minio-service:9000
s3.path-style-access=true
s3.region=${S3_REGION}
s3.aws-access-key=${MINIO_ROOT_USER}
s3.aws-secret-key=${MINIO_ROOT_PASSWORD}
EOF

cat >"$workdir/postgres.properties" <<EOF
connector.name=postgresql
connection-url=jdbc:postgresql://postgres-service:5432/${POSTGRES_DB}
connection-user=${POSTGRES_USER}
connection-password=${POSTGRES_PASSWORD}
EOF

# Trino catalog files carry the MinIO secret key and the Postgres password, so
# they are stored as a Secret (not a ConfigMap). Mounted as files, identical to
# a ConfigMap volume, but treated as secret material by Kubernetes.
echo "[•] Creating Trino catalog Secret..."
kubectl create secret generic trino-catalog-config \
  --from-file=iceberg.properties="$workdir/iceberg.properties" \
  --from-file=postgres.properties="$workdir/postgres.properties" \
  -n "$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

# Grafana datasources
cat >"$workdir/datasources.yaml" <<'EOF'
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus-service:9090
    isDefault: true
    editable: true
  - name: PostgreSQL
    type: postgres
    access: proxy
    url: postgres-service:5432
    database: ${POSTGRES_DB}
    user: ${POSTGRES_USER}
    secureJsonData:
      password: ${POSTGRES_PASSWORD}
    jsonData:
      sslmode: disable
      postgresVersion: 1500
    editable: true
EOF
# replace template vars
sed -i "s|\${POSTGRES_DB}|${POSTGRES_DB}|g; s|\${POSTGRES_USER}|${POSTGRES_USER}|g; s|\${POSTGRES_PASSWORD}|${POSTGRES_PASSWORD}|g" "$workdir/datasources.yaml"

# The datasources file embeds the Postgres password, so store it as a Secret.
echo "[•] Creating Grafana datasources Secret..."
kubectl create secret generic grafana-datasources \
  --from-file=datasources.yaml="$workdir/datasources.yaml" \
  -n "$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "[✓] Secrets and ConfigMaps created in namespace '$NAMESPACE'"
