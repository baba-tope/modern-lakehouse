# Cagridge Data Lakehouse

# Texas Gas Stations Analytics Platform

## 🏢 Overview

Cagridge operates 4 gas stations with convenience stores across Texas:

- **Houston** - Main Street Location
- **Dallas** - Central Avenue Location  
- **Austin** - Downtown Congress Avenue
- **San Antonio** - Commerce Street Plaza

This project implements a complete **Modern Data Lakehouse** architecture for analytics, reporting, and data management across all locations.

## 🏗️ Architecture

### Technology Stack

| Component | Technology | Version | Port | Purpose |
|-----------|-----------|---------|------|---------|
| **Dashboard** | Nginx + HTML/CSS/JS | 1.25-alpine | 30000 | Glassmorphic control panel |
| **Database** | PostgreSQL | 15.4-alpine | 30001 | Transactional data storage |
| **Object Storage** | MinIO | 2023-09-30 | 30002/30009 | S3-compatible data lake storage |
| **Catalog** | Project Nessie | 0.74.0 | 30003 | Git-like data versioning |
| **Query Engine** | Trino | 430 | 30004 | Distributed SQL query engine |
| **Transformation** | dbt | 1.6.2 | 30005 | Data transformation framework |
| **Orchestration** | Apache Airflow | 2.7.3 | 30006 | Workflow scheduling |
| **Monitoring** | Prometheus | 2.47.2 | 30007 | Metrics collection |
| **Visualization** | Grafana | 10.2.0 | 30008 | Analytics dashboards |
| **Metrics Exporter** | Postgres Exporter | v0.15.0 | - | PostgreSQL metrics for Prometheus |

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     Cagridge Data Lakehouse                      │
│                    (Kubernetes Cluster - Local)                  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────┐
│   Dashboard (30000) │  ← Glassmorphic UI
│   Nginx + Tailwind  │
└──────────┬──────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────────┐
│                     Service Layer                                 │
├───────────┬──────────┬───────────┬──────────┬───────────────────┤
│ Airflow   │ Trino    │ dbt       │ Nessie   │ Grafana           │
│ (30006)   │ (30004)  │ (30005)   │ (30003)  │ (30008)           │
│ Workflow  │ Query    │ Transform │ Catalog  │ Visualize         │
└───────────┴──────────┴───────────┴──────────┴───────────────────┘
           │                │              │
           ▼                ▼              ▼
┌──────────────────────────────────────────────────────────────────┐
│                     Storage Layer                                 │
├───────────────────────────────┬──────────────────────────────────┤
│   PostgreSQL (30001)          │   MinIO (30002/30009)            │
│   Transactional Data          │   Apache Iceberg Tables          │
│   - Stations                  │   - Raw Data                     │
│   - Sales                     │   - Processed Data               │
│   - Inventory                 │   - Historical Archives          │
└───────────────────────────────┴──────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────────┐
│                  Monitoring Layer                                 │
│   Prometheus (30007) → Grafana (30008)                           │
│   Metrics, Alerts, Performance Monitoring                         │
└──────────────────────────────────────────────────────────────────┘
```

## 📋 Prerequisites

- **Kubernetes Cluster** (kind recommended, Docker Desktop, or Minikube)
- **kubectl** CLI tool installed
- **MetalLB** will be automatically installed by deploy.sh
- **Minimum System Requirements:**
  - 8 GB RAM (16 GB recommended for multi-node cluster)
  - 4 CPU cores (8+ cores recommended)
  - 100 GB disk space (1 TB available for data storage)

## 🚀 Quick Start

### Step 1: Start Kubernetes Cluster

```bash
# Create the 6-node cluster
./manage-cluster.sh create

# For Docker Desktop with native Kubernetes: enable Kubernetes in settings, then verify
kubectl cluster-info

# For kind (Kubernetes in Docker) - recommended for multi-node testing:
kind create cluster --config kind-config.yaml  # if you have a config
# OR simple 3-node cluster:
kind create cluster -n cagridge   # (project) name = cagridge

# For Minikube:
minikube start --cpus=4 --memory=8192 --disk-size=50g
```

**Note**: This project uses MetalLB for LoadBalancer services. The `deploy.sh` script will automatically install MetalLB v0.13.12 if not already present.

### 2. Configure Environment Variables

**IMPORTANT**: All credentials are managed through the `.env` file. Never hardcode credentials!

```bash
# The .env file already exists with secure credentials
# Review and update if needed:

# Database Configuration
# - POSTGRES_USER
# - POSTGRES_PASSWORD
# - POSTGRES_DB
# - POSTGRES_PORT

# MinIO/S3 Configuration
# - MINIO_ROOT_USER
# - MINIO_ROOT_PASSWORD
# - S3_REGION (default: us-east-1 for MinIO compatibility)

# Airflow Configuration
# - AIRFLOW_FERNET_KEY
# - AIRFLOW_SECRET_KEY

# Grafana Configuration
# - GF_SECURITY_ADMIN_USER
# - GF_SECURITY_ADMIN_PASSWORD
# - GF_INSTALL_PLUGINS
# - GF_SERVER_ROOT_URL
# - GF_ANALYTICS_REPORTING_ENABLED
# - GF_ANALYTICS_CHECK_FOR_UPDATES

# Kubernetes Configuration
# - NAMESPACE (default: texas-gas-lakehouse)

# MetalLB LoadBalancer IP Configuration
# - METALLB_IP_RANGE
# - DASHBOARD_IP
# - POSTGRES_IP
# - MINIO_IP
# - NESSIE_IP
# - TRINO_IP
# - DBT_IP
# - AIRFLOW_IP
# - PROMETHEUS_IP
# - GRAFANA_IP

```

### 3. Deploy All Services (Automated)

```bash
# From the project root
./deploy.sh
```

### 4. Manual Deployment (Alternative)

If you prefer manual steps:

```bash
# 1. Create namespace
kubectl apply -f k8s/namespace.yaml

# 2. Create secrets and configmaps from .env
./create-secrets.sh

# 3. Deploy services
kubectl apply -f k8s/postgres.yaml
kubectl apply -f k8s/minio.yaml
kubectl apply -f k8s/nessie.yaml
kubectl apply -f k8s/trino.yaml
kubectl apply -f k8s/dbt.yaml
kubectl apply -f k8s/airflow.yaml
kubectl apply -f k8s/prometheus.yaml
kubectl apply -f k8s/grafana.yaml

# 4. Create dashboard ConfigMap and deploy
kubectl create configmap dashboard-html --from-file=dashboard/index.html -n ${NAMESPACE:-texas-gas-lakehouse}
kubectl apply -f k8s/dashboard.yaml
```

### 3. Verify Deployment

```bash
kubectl get pods -n ${NAMESPACE:-texas-gas-lakehouse}
kubectl get svc -n ${NAMESPACE:-texas-gas-lakehouse}
kubectl get pvc -n ${NAMESPACE:-texas-gas-lakehouse}
```

### 4. Access Services

All services are accessible via **MetalLB LoadBalancer IPs** (configured in `.env`):

The `deploy.sh` script automatically reads IP addresses from your `.env` file:

- **Dashboard**: http://${DASHBOARD_IP}:30000
- **PostgreSQL**: ${POSTGRES_IP}:30001
- **MinIO API**: http://${MINIO_IP}:30002
- **MinIO Console**: http://${MINIO_IP}:30009
- **Nessie API**: http://${NESSIE_IP}:30003/api/v1
- **Trino UI**: http://${TRINO_IP}:30004
- **dbt Server**: http://${DBT_IP}:30005
- **Airflow**: http://${AIRFLOW_IP}:30006
- **Prometheus**: http://${PROMETHEUS_IP}:30007
- **Grafana**: http://${GRAFANA_IP}:30008

**Customize IPs**: Edit the `.env` file to change IP addresses before deployment:

```bash
# MetalLB LoadBalancer IP Configuration
METALLB_IP_RANGE=<your-range>
DASHBOARD_IP=<your-ip>
POSTGRES_IP=<your-ip>
# ... see .env for all IP variables
```

**Add friendly hostnames** (optional):

```
${DASHBOARD_IP}    cagridge-dashboard
${POSTGRES_IP}     cagridge-postgres
${MINIO_IP}        cagridge-minio
# ... etc (check your .env for actual IPs)
```

<details>
<summary><b>Alternative: Direct NodePort Access</b></summary>

If MetalLB isn't working, access services directly via NodePort on localhost:

```bash
# Services are accessible on localhost with NodePort
# Dashboard:   http://localhost:30000
# PostgreSQL:  localhost:30001
# MinIO API:   http://localhost:30002
# MinIO UI:    http://localhost:30009
# Nessie:      http://localhost:30003
# Trino:       http://localhost:30004
# dbt:         http://localhost:30005
# Airflow:     http://localhost:30006
# Prometheus:  http://localhost:30007
# Grafana:     http://localhost:30008
```

Or set up manual port forwarding for specific services:

```bash
kubectl port-forward -n texas-gas-lakehouse svc/dashboard-service 30000:80
```

</details>

## 🗄️ Database Setup

### Initialize PostgreSQL

```bash
kubectl cp sql/init.sql ${NAMESPACE:-texas-gas-lakehouse}/postgres-0:/tmp/init.sql
kubectl exec -it postgres-0 -n ${NAMESPACE:-texas-gas-lakehouse} -- psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /tmp/init.sql
```

### Connect to PostgreSQL

```bash
# Using kubectl
kubectl exec -it postgres-0 -n ${NAMESPACE:-texas-gas-lakehouse} -- psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"

# Using local psql client (via MetalLB IP from .env)
psql -h "$POSTGRES_IP" -p 30001 -U "$POSTGRES_USER" -d "$POSTGRES_DB"
```

## 📊 MinIO Setup

### Initialize MinIO Buckets

```bash
# Access MinIO pod
kubectl exec -it minio-0 -n ${NAMESPACE:-texas-gas-lakehouse} -- sh

# Inside the pod, create buckets (adjust creds if changed)
mc alias set local http://localhost:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"
mc mb local/lakehouse
mc mb local/warehouse
mc mb local/raw-data
mc mb local/processed-data
mc mb local/backups
```

Or use the MinIO Console at http://${MINIO_IP}:30009 (IP from .env)

## 🔧 Trino Configuration

### Create Iceberg Tables

```sql
-- Connect to Trino UI at http://${TRINO_IP}:30004 (IP from .env)

-- Create schema
CREATE SCHEMA iceberg.cagridge WITH (location = 's3://lakehouse/cagridge');

-- Create sample table
CREATE TABLE iceberg.cagridge.fuel_sales (
    station_id INTEGER,
    transaction_date TIMESTAMP,
    fuel_type VARCHAR,
    gallons DECIMAL(10,3),
    price_per_gallon DECIMAL(6,3),
    total_amount DECIMAL(10,2)
) WITH (
    format = 'PARQUET',
    partitioning = ARRAY['month(transaction_date)']
);
```

## 🌊 Airflow DAGs

### Create Sample DAG

```bash
# Copy DAG files to Airflow
kubectl cp airflow/dags/ ${NAMESPACE:-texas-gas-lakehouse}/airflow-webserver-0:/opt/airflow/dags/
```

Sample DAG structure:

```python
from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime, timedelta

default_args = {
    'owner': 'cagridge',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

dag = DAG(
    'cagridge_daily_etl',
    default_args=default_args,
    description='Daily ETL for Cagridge stations',
    schedule_interval='0 2 * * *',
    catchup=False
)

# Define tasks...
```

## 📈 Monitoring

### Prometheus Targets

Prometheus automatically scrapes metrics from:

- PostgreSQL (port 5432)
- MinIO (port 9000)
- Trino (port 8080)
- Airflow (port 8080)
- Nessie (port 19120)

### Grafana Dashboards

1. Access Grafana at <http://localhost:30008>
2. Login: `${GF_SECURITY_ADMIN_USER}` / `${GF_SECURITY_ADMIN_PASSWORD}` (from .env)
3. Pre-configured data sources:
   - Prometheus (metrics)
   - PostgreSQL (data)

## 🔐 Security Configuration

### Credentials Management

**All credentials are managed via the `.env` file.** No credentials are hardcoded!

| Service | Username Source | Password Source | Notes |
|---------|----------------|-----------------|-------|
| PostgreSQL | `POSTGRES_USER` from .env | `POSTGRES_PASSWORD` from .env | Auto-created secret |
| MinIO | `MINIO_ROOT_USER` from .env | `MINIO_ROOT_PASSWORD` from .env | Auto-created secret |
| Airflow | `AIRFLOW_USERNAME` from .env | `AIRFLOW_PASSWORD` from .env | Change after first login |
| Grafana | `GF_SECURITY_ADMIN_USER` from .env | `GF_SECURITY_ADMIN_PASSWORD` from .env | Change after first login |

See `.env.example` for variables and update your `.env` accordingly.

### Update Credentials

```bash
# 1. Update .env file with new credentials
# Edit .env file and change the passwords

# 2. Recreate secrets
./create-secrets.sh

# 3. Restart affected services
kubectl rollout restart statefulset postgres -n texas-gas-lakehouse
kubectl rollout restart statefulset minio -n texas-gas-lakehouse
kubectl rollout restart statefulset trino -n texas-gas-lakehouse
```

### Generate Strong Passwords

```bash
# Generate a secure password
tr -dc 'A-Za-z0-9_-' </dev/urandom | head -c 32; echo
```

## 🧪 Testing

### Verify Services

```bash
kubectl exec -it postgres-0 -n ${NAMESPACE:-texas-gas-lakehouse} -- psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT version();"
kubectl exec -it minio-0 -n ${NAMESPACE:-texas-gas-lakehouse} -- curl -sS http://localhost:9000/minio/health/live
kubectl exec -it nessie-0 -n ${NAMESPACE:-texas-gas-lakehouse} -- curl -sS http://localhost:19120/api/v1/config
kubectl exec -it trino-0 -n ${NAMESPACE:-texas-gas-lakehouse} -- curl -sS http://localhost:8080/v1/info
```

## 📦 Backup & Restore

### Backup PostgreSQL

```bash
# Backup database
kubectl exec postgres-0 -n ${NAMESPACE:-texas-gas-lakehouse} -- pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" > backup.sql

# Restore database
kubectl exec -i postgres-0 -n ${NAMESPACE:-texas-gas-lakehouse} -- psql -U "$POSTGRES_USER" "$POSTGRES_DB" < backup.sql
```

### Backup MinIO

```bash
# Backup MinIO data
kubectl exec -it minio-0 -n texas-gas-lakehouse -- mc mirror local/lakehouse /backup/lakehouse
```

## 🛠️ Troubleshooting

### Pods Not Starting

```bash
kubectl get pods -n ${NAMESPACE:-texas-gas-lakehouse}
kubectl logs <pod-name> -n ${NAMESPACE:-texas-gas-lakehouse}
kubectl describe pod <pod-name> -n ${NAMESPACE:-texas-gas-lakehouse}
```

### Persistent Volume Issues

```bash
kubectl get pvc -n ${NAMESPACE:-texas-gas-lakehouse}
# Note: This project uses dynamic PVC provisioning via the cluster's default StorageClass.
```

### Service Not Accessible

**For kind clusters or Windows users**:
Use NodePort access on localhost (ports 30000-30009) or set up manual port forwarding:

**For debugging individual services**:

```bash
kubectl get endpoints -n ${NAMESPACE:-texas-gas-lakehouse}
# Port-forward a specific service:
kubectl port-forward -n ${NAMESPACE:-texas-gas-lakehouse} svc/postgres-service 30001:5432
```

## 🔄 Scaling

### Scale Deployments

```bash
# Scale dashboard (stateless; safe to scale)
kubectl scale deployment dashboard --replicas=2 -n ${NAMESPACE:-texas-gas-lakehouse}
# Stateful services (PostgreSQL, MinIO, Trino, Airflow, Nessie) remain at 1 replica in this setup.
```

## 📝 Development

### Local Development

```bash
kubectl logs -f <pod-name> -n ${NAMESPACE:-texas-gas-lakehouse}
kubectl exec -it <pod-name> -n ${NAMESPACE:-texas-gas-lakehouse} -- /bin/bash
kubectl cp local-file.txt ${NAMESPACE:-texas-gas-lakehouse}/<pod-name>:/remote-path/
kubectl cp ${NAMESPACE:-texas-gas-lakehouse}/<pod-name>:/remote-file.txt ./local-file.txt
```

## 🗑️ Cleanup

### Delete All Resources

```bash
./cleanup.sh
```

## 📚 Additional Resources

- [Apache Iceberg Documentation](https://iceberg.apache.org/)
- [Project Nessie Documentation](https://projectnessie.org/)
- [Trino Documentation](https://trino.io/docs/current/)
- [dbt Documentation](https://docs.getdbt.com/)
- [Apache Airflow Documentation](https://airflow.apache.org/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

## 👥 Team & Support

**Cagridge IT Department**

- Email: <it@cagridge.com>
- Support: <support@cagridge.com>

## 📄 License

Proprietary - Cagridge Gas © 2025

---

**Last Updated:** November 2, 2025
**Version:** 1.0.0
**Project:** Cagridge Data Lakehouse
**Location:** Texas (Houston, Dallas, Austin, San Antonio)
