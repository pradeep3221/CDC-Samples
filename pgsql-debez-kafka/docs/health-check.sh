#!/bin/bash

# Health Check Script
# Verifies all components are running and healthy

NAMESPACE="cdc-system"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

function check_pod() {
    local pod_label=$1
    local expected_count=$2
    
    local ready=$(kubectl get pods -n $NAMESPACE -l $pod_label -o jsonpath='{.items[?(@.status.conditions[?(@.type=="Ready")].status=="True")].metadata.name}' | wc -w)
    
    if [ "$ready" -eq "$expected_count" ]; then
        echo -e "${GREEN}✓${NC} $pod_label: Ready ($ready/$expected_count)"
    else
        echo -e "${RED}✗${NC} $pod_label: Not ready ($ready/$expected_count)"
        kubectl describe pods -n $NAMESPACE -l $pod_label
    fi
}

function check_service() {
    local service=$1
    local port=$2
    
    local ip=$(kubectl get svc $service -n $NAMESPACE -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
    
    if [ -n "$ip" ] && [ "$ip" != "None" ]; then
        echo -e "${GREEN}✓${NC} Service $service: Available ($ip:$port)"
    else
        echo -e "${RED}✗${NC} Service $service: Not available"
    fi
}

function check_debezium_connector() {
    local pod=$(kubectl get pods -n $NAMESPACE -l app=debezium-connect -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -n "$pod" ]; then
        echo "Checking Debezium connector status..."
        kubectl exec $pod -n $NAMESPACE -- curl -s http://localhost:8083/connectors/postgres-cdc-connector/status 2>/dev/null | grep -q "RUNNING"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓${NC} Debezium Connector: Running"
        else
            echo -e "${YELLOW}!${NC} Debezium Connector: Check status manually"
        fi
    fi
}

echo "=========================================="
echo "Health Check - CDC Pipeline (PostgreSQL)"
echo "=========================================="
echo ""

# Check pods
echo "Checking Pods:"
check_pod "app=zookeeper" 1
check_pod "app=kafka-broker" 1
check_pod "app=postgres-db" 1
check_pod "app=rabbitmq" 1
check_pod "app=debezium-connect" 1
echo ""

# Check services
echo "Checking Services:"
check_service "zookeeper" 2181
check_service "kafka-broker" 9092
check_service "postgres-db" 5432
check_service "rabbitmq" 5672
check_service "debezium-connect" 8083
echo ""

# Check Debezium connector
check_debezium_connector
echo ""

# Check persistent volumes
echo "Checking Persistent Volumes:"
kubectl get pvc -n $NAMESPACE

echo ""
echo "=========================================="
echo "Health check complete!"
echo "=========================================="
