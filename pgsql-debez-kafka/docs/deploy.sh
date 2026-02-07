#!/bin/bash

# Deploy CDC Pipeline on Kubernetes
# This script sets up the complete CDC system

set -e

NAMESPACE="cdc-system"
TIMEOUT=300

echo "=========================================="
echo "CDC Pipeline Deployment Script (PostgreSQL)"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 1. Create namespace and secrets
log_info "Creating namespace and secrets..."
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/secrets.yaml

# 2. Deploy Zookeeper
log_info "Deploying Zookeeper..."
kubectl apply -f k8s/zookeeper.yaml
log_info "Waiting for Zookeeper to be ready..."
kubectl wait --for=condition=ready pod -l app=zookeeper -n $NAMESPACE --timeout=${TIMEOUT}s
log_info "Zookeeper is ready!"

# 3. Deploy Kafka
log_info "Deploying Kafka..."
kubectl apply -f k8s/kafka.yaml
log_info "Waiting for Kafka to be ready..."
kubectl wait --for=condition=ready pod -l app=kafka-broker -n $NAMESPACE --timeout=${TIMEOUT}s
log_info "Kafka is ready!"

# 4. Deploy PostgreSQL
log_info "Deploying PostgreSQL..."
kubectl apply -f k8s/postgres-init-config.yaml
kubectl apply -f k8s/postgres.yaml
log_info "Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l app=postgres-db -n $NAMESPACE --timeout=${TIMEOUT}s
log_info "PostgreSQL is ready!"

# 5. Deploy RabbitMQ
log_info "Deploying RabbitMQ..."
kubectl apply -f k8s/rabbitmq.yaml
log_info "Waiting for RabbitMQ to be ready..."
kubectl wait --for=condition=ready pod -l app=rabbitmq -n $NAMESPACE --timeout=${TIMEOUT}s
log_info "RabbitMQ is ready!"

# 6. Deploy Debezium ConfigMap and Connect
log_info "Deploying Debezium ConfigMap..."
kubectl apply -f k8s/configmap.yaml

log_info "Deploying Debezium Connect..."
kubectl apply -f k8s/debezium-connect.yaml
log_info "Waiting for Debezium Connect to be ready..."
kubectl wait --for=condition=ready pod -l app=debezium-connect -n $NAMESPACE --timeout=${TIMEOUT}s
log_info "Debezium Connect is ready!"

# 7. Summary
log_info "=========================================="
log_info "Deployment complete!"
log_info "=========================================="
log_info ""
log_info "Services deployed in namespace: $NAMESPACE"
log_info ""
log_info "To access services:"
log_info "  PostgreSQL: kubectl port-forward svc/postgres-db 5432:5432"
log_info "  Debezium: kubectl port-forward svc/debezium-connect-lb 8083:8083"
log_info "  RabbitMQ Management: kubectl port-forward svc/rabbitmq-lb 15672:15672"
log_info ""
log_info "Next steps:"
log_warn "  1. Create Debezium connector:"
log_warn "     kubectl port-forward svc/debezium-connect-lb 8083:8083 &"
log_warn "     curl -X POST http://localhost:8083/connectors -H 'Content-Type: application/json' -d @debezium/connector-config.json"
log_warn "  2. Deploy consumer application: kubectl apply -f k8s/cdc-consumer.yaml"
log_warn "  3. Monitor logs: kubectl logs -f <pod-name> -n $NAMESPACE"
