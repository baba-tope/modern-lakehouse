#!/usr/bin/env bash
set -euo pipefail

# Cagridge Data Lakehouse - Cleanup (bash)

project_root="$(cd "$(dirname "$0")" && pwd)"
cd "$project_root"

if [[ -f .env ]]; then set -a; source ./.env; set +a; fi
NAMESPACE="${NAMESPACE:-texas-gas-lakehouse}"

read -rp "This will delete namespace '$NAMESPACE' and all resources in it. Continue? (y/N): " ans
if [[ "${ans:-N}" != "y" && "${ans:-N}" != "Y" ]]; then
  echo "Aborted."
  exit 0
fi

echo "[•] Deleting namespace '$NAMESPACE'..."
kubectl delete namespace "$NAMESPACE" --ignore-not-found

echo "[i] If you used dynamic provisioning, volumes are reclaimed by the storage class. If any PVs remain, delete them manually if desired."
echo "[✓] Cleanup complete"
