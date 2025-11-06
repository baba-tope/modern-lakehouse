#!/usr/bin/env bash
set -euo pipefail

# Helper script to run dbt commands in the dbt container

# Load env to get NAMESPACE
if [[ -f .env ]]; then
  set -a; source ./.env; set +a
fi
NAMESPACE="${NAMESPACE:-texas-gas-lakehouse}"

# Get the dbt pod name
DBT_POD=$(kubectl get pod -n "$NAMESPACE" -l app=dbt-server -o jsonpath='{.items[0].metadata.name}')

if [[ -z "$DBT_POD" ]]; then
  echo "[✗] dbt pod not found in namespace $NAMESPACE" >&2
  exit 1
fi

echo "[•] Found dbt pod: $DBT_POD"

# Copy dbt project files to the pod
echo "[•] Copying dbt project files to pod..."
kubectl exec -n "$NAMESPACE" "$DBT_POD" -- mkdir -p /dbt
kubectl cp dbt/. "$NAMESPACE/$DBT_POD:/dbt/"

echo "[•] Setting up dbt profiles..."
kubectl exec -n "$NAMESPACE" "$DBT_POD" -- bash -c "mkdir -p /root/.dbt && cp /dbt-profiles/profiles.yml /root/.dbt/profiles.yml"

# Run dbt commands
if [[ $# -eq 0 ]]; then
  # Default: run dbt debug and dbt run
  echo "[•] Running dbt debug..."
  kubectl exec -n "$NAMESPACE" "$DBT_POD" -- bash -c "cd /dbt && dbt debug"
  
  echo "[•] Running dbt deps (install dependencies)..."
  kubectl exec -n "$NAMESPACE" "$DBT_POD" -- bash -c "cd /dbt && dbt deps" || true
  
  echo "[•] Running dbt run..."
  kubectl exec -n "$NAMESPACE" "$DBT_POD" -- bash -c "cd /dbt && dbt run"
  
  echo "[✓] dbt run completed successfully"
else
  # Run custom dbt command
  echo "[•] Running: dbt $*"
  kubectl exec -n "$NAMESPACE" "$DBT_POD" -- bash -c "cd /dbt && dbt $*"
fi

echo ""
echo "Usage examples:"
echo "  ./run-dbt.sh                    # Run dbt debug and dbt run"
echo "  ./run-dbt.sh test               # Run dbt tests"
echo "  ./run-dbt.sh run --select marts # Run only marts models"
echo "  ./run-dbt.sh docs generate      # Generate documentation"

