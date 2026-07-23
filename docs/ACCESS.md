# Texas Gas Lakehouse - Access Guide

All services are accessible via **localhost** through Nginx Ingress Controller!

## Service URLs (Direct NodePort Access) OK WORKING

Access services from your Windows browser using **NodePorts** (localhost:3000X):

| Service | URL | Port | Description |
| :--- | :--- | :--- | :--- |
| **Dashboard** | <http://localhost:30000> | 30000 | Main control panel |
| **Grafana** | <http://localhost:30008> | 30008 | Data visualization & dashboards |
| **MinIO Console** | <http://localhost:30009> | 30009 | Object storage console (UI) |
| **MinIO API** | <http://localhost:30002> | 30002 | S3-compatible API endpoint |
| **Airflow** | <http://localhost:30006> | 30006 | Workflow orchestration |
| **Trino** | <http://localhost:30004> | 30004 | Query engine UI |
| **Prometheus** | <http://localhost:30007> | 30007 | Metrics & monitoring |
| **Nessie** | <http://localhost:30003> | 30003 | Data catalog API |
| **PostgreSQL** | localhost:30001 | 30001 | Database (CLI access only) |

## OK Verification Steps

1. **Check all pods are running**:

   ```powershell
   kubectl get pods -n texas-gas-lakehouse
   ```

   All pods should show `READY` status.

2. **Check Ingress status**:

   ```powershell
   kubectl get ingress -n texas-gas-lakehouse
   ```

   Should show `ADDRESS: localhost`.

3. **Test Dashboard**:
   Open <http://localhost/> in your browser.

4. **Test Grafana**:
   Open <http://localhost/grafana> in your browser.

## Troubleshooting

### If services are not accessible

1. **Check Nginx Ingress Controller**:

   ```powershell
   kubectl get pods -n ingress-nginx
   ```

2. **Check service endpoints**:

   ```powershell
   kubectl get svc -n texas-gas-lakehouse
   ```

3. **View Ingress logs**:

   ```powershell
   kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
   ```

4. **Verify port mappings** (from kind container):

   ```powershell
   docker exec -it cagridge-control-plane netstat -tlnp | findstr ":80"
   ```
