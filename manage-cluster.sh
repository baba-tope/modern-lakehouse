#!/usr/bin/env bash
set -euo pipefail

# Cagridge Data Lakehouse - kind Cluster Management Script

CLUSTER_NAME="cagridge"
CONFIG_FILE="kind-config.yaml"

show_help() {
  cat <<EOF
Usage: ./manage-cluster.sh [command]

Commands:
  create    - Create a new kind cluster (6 worker nodes)
  delete    - Delete the existing kind cluster
  status    - Show cluster status and nodes
  info      - Display cluster information
  reset     - Delete and recreate the cluster
  help      - Show this help message

Examples:
  ./manage-cluster.sh create
  ./manage-cluster.sh status
  ./manage-cluster.sh reset
EOF
}

create_cluster() {
  echo "Creating kind cluster: $CLUSTER_NAME"
  echo "Configuration: 6 worker nodes + 1 control plane = 7 total nodes"
  
  if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    echo "Cluster '$CLUSTER_NAME' already exists!"
    echo "Run './manage-cluster.sh delete' first or use './manage-cluster.sh reset'"
    exit 1
  fi
  
  kind create cluster --config "$CONFIG_FILE"
  
  echo ""
  echo "✓ Cluster created successfully!"
  echo ""
  echo "Next steps:"
  echo "  1. Deploy the lakehouse: ./deploy.sh"
  echo "  2. Check status: ./manage-cluster.sh status"
}

delete_cluster() {
  echo "Deleting kind cluster: $CLUSTER_NAME"
  
  if ! kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    echo "Cluster '$CLUSTER_NAME' does not exist"
    exit 1
  fi
  
  kind delete cluster --name "$CLUSTER_NAME"
  echo "✓ Cluster deleted successfully!"
}

show_status() {
  if ! kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    echo "Cluster '$CLUSTER_NAME' does not exist"
    echo "Run './manage-cluster.sh create' to create it"
    exit 1
  fi
  
  echo "=== Cluster: $CLUSTER_NAME ==="
  echo ""
  
  echo "Nodes:"
  kubectl get nodes -o wide
  
  echo ""
  echo "Cluster Info:"
  kubectl cluster-info
  
  echo ""
  echo "Resource Usage:"
  kubectl top nodes 2>/dev/null || echo "Metrics server not installed (optional)"
  
  echo ""
  echo "Namespaces:"
  kubectl get namespaces
}

show_info() {
  if ! kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    echo "Cluster '$CLUSTER_NAME' does not exist"
    exit 1
  fi
  
  echo "=== Kind Cluster Information ==="
  echo ""
  echo "Cluster Name: $CLUSTER_NAME"
  echo "Config File: $CONFIG_FILE"
  echo ""
  
  echo "Docker Containers (cluster nodes):"
  docker ps --filter "label=io.x-k8s.kind.cluster=$CLUSTER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
  
  echo ""
  echo "Kubernetes Context:"
  kubectl config current-context
  
  echo ""
  echo "API Server:"
  kubectl cluster-info | grep "control plane"
}

reset_cluster() {
  echo "This will delete and recreate the cluster"
  read -p "Continue? (y/N): " -n 1 -r
  echo
  
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 0
  fi
  
  if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    delete_cluster
    echo ""
  fi
  
  create_cluster
}

# Main
case "${1:-help}" in
  create)
    create_cluster
    ;;
  delete)
    delete_cluster
    ;;
  status)
    show_status
    ;;
  info)
    show_info
    ;;
  reset)
    reset_cluster
    ;;
  help|--help|-h)
    show_help
    ;;
  *)
    echo "Unknown command: $1"
    echo ""
    show_help
    exit 1
    ;;
esac
