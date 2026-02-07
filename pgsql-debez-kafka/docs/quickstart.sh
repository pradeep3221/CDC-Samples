#!/bin/bash

# Quick Start Guide Script
# This script provides quick commands for common operations

NAMESPACE="cdc-system"

function show_help() {
    echo "CDC Pipeline Quick Start Commands"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  status              - Show status of all pods"
    echo "  logs-debezium       - Tail Debezium logs"
    echo "  logs-consumer       - Tail consumer logs"
    echo "  logs-postgres       - Tail PostgreSQL logs"
    echo "  logs-kafka          - Tail Kafka logs"
    echo "  port-forward-pg     - Port forward PostgreSQL (5432:5432)"
    echo "  port-forward-debez  - Port forward Debezium (8083:8083)"
    echo "  port-forward-rabbitmq - Port forward RabbitMQ (15672:15672)"
    echo "  check-connector     - Check Debezium connector status"
    echo "  test-data           - Insert test data"
    echo "  list-topics         - List Kafka topics"
    echo "  describe-topic      - Describe topic (requires TOPIC env var)"
    echo "  cleanup             - Delete all resources"
    echo "  help                - Show this help message"
}

case "${1:-help}" in
    status)
        echo "Pod status in namespace: $NAMESPACE"
        kubectl get pods -n $NAMESPACE
        echo ""
        echo "Services:"
        kubectl get svc -n $NAMESPACE
        ;;
    logs-debezium)
        kubectl logs -f deployment/debezium-connect -n $NAMESPACE
        ;;
    logs-consumer)
        kubectl logs -f deployment/cdc-consumer -n $NAMESPACE
        ;;
    logs-postgres)
        kubectl logs -f statefulset/postgres-db -n $NAMESPACE
        ;;
    logs-kafka)
        kubectl logs -f statefulset/kafka-broker -n $NAMESPACE
        ;;
    port-forward-pg)
        echo "Forwarding PostgreSQL to localhost:5432"
        kubectl port-forward -n $NAMESPACE svc/postgres-db 5432:5432
        ;;
    port-forward-debez)
        echo "Forwarding Debezium to localhost:8083"
        kubectl port-forward -n $NAMESPACE svc/debezium-connect-lb 8083:8083
        ;;
    port-forward-rabbitmq)
        echo "Forwarding RabbitMQ to localhost:15672"
        kubectl port-forward -n $NAMESPACE svc/rabbitmq-lb 15672:15672
        ;;
    check-connector)
        echo "Checking Debezium connector status..."
        curl -s http://localhost:8083/connectors/postgres-cdc-connector/status | jq
        ;;
    test-data)
        echo "Inserting test data..."
        POD=$(kubectl get pods -n $NAMESPACE -l app=postgres-db -o jsonpath='{.items[0].metadata.name}')
        kubectl exec -it $POD -n $NAMESPACE -- psql -U postgres -d testdb << EOF
INSERT INTO public.customers (first_name, last_name, email, phone_number)
VALUES ('Test', 'User', 'test@example.com', '555-0001');
SELECT COUNT(*) FROM public.customers;
EOF
        echo "Test data inserted!"
        ;;
    list-topics)
        POD=$(kubectl get pods -n $NAMESPACE -l app=kafka-broker -o jsonpath='{.items[0].metadata.name}')
        kubectl exec -it $POD -n $NAMESPACE -- /usr/local/bin/kafka-topics \
            --bootstrap-server localhost:9092 --list
        ;;
    describe-topic)
        if [ -z "$TOPIC" ]; then
            echo "Please set TOPIC environment variable: export TOPIC=postgresql.public.customers"
            exit 1
        fi
        POD=$(kubectl get pods -n $NAMESPACE -l app=kafka-broker -o jsonpath='{.items[0].metadata.name}')
        kubectl exec -it $POD -n $NAMESPACE -- /usr/local/bin/kafka-topics \
            --bootstrap-server localhost:9092 --describe --topic $TOPIC
        ;;
    cleanup)
        echo "Cleaning up resources in namespace: $NAMESPACE"
        read -p "Are you sure? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            kubectl delete namespace $NAMESPACE
            echo "Namespace deleted!"
        fi
        ;;
    help|*)
        show_help
        ;;
esac
