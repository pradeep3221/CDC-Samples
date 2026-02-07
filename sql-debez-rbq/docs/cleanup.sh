#!/bin/bash

# Cleanup Script
# Removes all resources and data

NAMESPACE="cdc-system"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

function log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

function log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo "=========================================="
echo "CDC Pipeline Cleanup"
echo "=========================================="
echo ""
log_warn "WARNING: This will delete all resources in namespace: $NAMESPACE"
log_warn "All data, including persistent volumes, will be LOST!"
echo ""
read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirmation

if [ "$confirmation" != "yes" ]; then
    log_info "Cleanup cancelled"
    exit 0
fi

echo ""
log_info "Starting cleanup..."
echo ""

# Delete deployments
log_info "Deleting deployments..."
kubectl delete deployment --all -n $NAMESPACE --ignore-not-found=true

# Delete StatefulSets
log_info "Deleting StatefulSets..."
kubectl delete statefulset --all -n $NAMESPACE --ignore-not-found=true

# Delete services
log_info "Deleting services..."
kubectl delete service --all -n $NAMESPACE --ignore-not-found=true

# Delete PVCs
log_info "Deleting PersistentVolumeClaims..."
kubectl delete pvc --all -n $NAMESPACE --ignore-not-found=true

# Delete ConfigMaps
log_info "Deleting ConfigMaps..."
kubectl delete configmap --all -n $NAMESPACE --ignore-not-found=true

# Delete Secrets
log_info "Deleting Secrets..."
kubectl delete secret --all -n $NAMESPACE --ignore-not-found=true

# Wait for resources to be deleted
log_info "Waiting for resources to be deleted..."
sleep 10

# Delete namespace
log_info "Deleting namespace..."
kubectl delete namespace $NAMESPACE --ignore-not-found=true

# Wait for namespace to be deleted
log_info "Waiting for namespace deletion..."
kubectl wait --for=delete ns/$NAMESPACE --timeout=60s 2>/dev/null || true

echo ""
log_info "=========================================="
log_info "Cleanup complete!"
log_info "=========================================="
log_warn "Note: Any persistent volumes may still exist on your cluster"
log_warn "To fully clean up, manually delete any remaining PVs"
