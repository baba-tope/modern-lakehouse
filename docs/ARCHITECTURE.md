# Cagridge Data Lakehouse - Project Structure

## Folder Structure

```tree
modern-lakehouse/
├── .env                              # Environment variables
├── .gitignore                        # Git ignore rules
├── README.md                         # Complete documentation
├── deploy.sh                         # Deployment script (bash)
├── port-forward.sh                   # Port forwarding for kind/Windows (bash)
├── cleanup.sh                        # Cleanup script (bash)
├── status.sh                         # Status check script (bash)
│
├── k8s/                              # Kubernetes manifests
│   ├── namespace.yaml                # Namespace
│   ├── postgres.yaml                 # PostgreSQL StatefulSet (NodePort 30001)
│   ├── minio.yaml                    # MinIO StatefulSet (NodePorts 30002, 30009)
│   ├── nessie.yaml                   # Nessie StatefulSet (NodePort 30003)
│   ├── trino.yaml                    # Trino StatefulSet (NodePort 30004)
│   ├── dbt.yaml                      # dbt Deployment (NodePort 30005)
│   ├── airflow.yaml                  # Airflow StatefulSet (NodePort 30006)
│   ├── prometheus.yaml               # Prometheus Deployment (NodePort 30007)
│   ├── grafana.yaml                  # Grafana Deployment (NodePort 30008)
│   └── dashboard.yaml                # Dashboard Deployment (NodePort 30000)
│
├── dashboard/                        # Web dashboard
│   └── index.html                    # Dashboard UI
│
├── sql/                              # SQL scripts
│   └── init.sql                      # Database initialization
│
├── dbt/                              # dbt project
│   ├── dbt_project.yml               # dbt configuration
│   └── models/
│       ├── schema.yml                # Model definitions
│       ├── staging/
│       │   ├── stg_fuel_sales.sql    # Staging: fuel sales
│       │   └── stg_store_sales.sql   # Staging: store sales
│       └── mart/
│           └── daily_station_performance.sql  # Mart: daily metrics
│
└── airflow/                          # Airflow DAGs
    └── dags/
        ├── cagridge_daily_etl.py     # Daily ETL pipeline
        └── cagridge_inventory_management.py  # Inventory monitoring
```

## Port Mapping

| Port  | Service          | Purpose                     |
|-------|------------------|-----------------------------|
| 30000 | Dashboard        | Web UI control panel        |
| 30001 | PostgreSQL       | Relational database         |
| 30002 | MinIO API        | Object storage API          |
| 30003 | Nessie           | Data catalog API            |
| 30004 | Trino            | Query engine UI             |
| 30005 | dbt              | Transformation server       |
| 30006 | Airflow          | Workflow orchestration UI   |
| 30007 | Prometheus       | Metrics monitoring          |
| 30008 | Grafana          | Analytics dashboards        |
| 30009 | MinIO Console    | Object storage web UI       |

## Data Flow

![data_lakehouse_architecture_diagram](data_lakehouse_architecture_diagram.png)

## Component Versions

All versions are production-stable and tested for compatibility:

- **PostgreSQL**: 15.4-alpine
- **MinIO**: RELEASE.2023-09-30T07-02-29Z
- **Nessie**: 0.74.0
- **Trino**: 430
- **dbt-trino**: 1.6.2
- **Apache Airflow**: 2.7.3-python3.10
- **Prometheus**: v2.47.2
- **Grafana**: 10.2.0
- **Nginx**: 1.25-alpine

## Storage Requirements

- PostgreSQL: 200 GB
- MinIO: 600 GB
- Nessie: 10 GB
- Trino: 20 GB
- dbt: 10 GB
- Airflow: 20 GB
- Prometheus: 20 GB
- Grafana: 10 GB

This configuration targets a 10-node-capable cluster with ~1 TB available capacity and comfortably supports ~5,776 monthly transactions (very low TPS) with headroom for growth. PVCs are dynamically provisioned via your cluster's default StorageClass for multi-node compatibility.

**Total**: ~890 GB baseline
