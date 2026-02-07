#!/bin/bash

# Testing and Monitoring Guide for PostgreSQL CDC

NAMESPACE="cdc-system"

echo "=========================================="
echo "CDC Pipeline - Testing & Monitoring Guide"
echo "=========================================="
echo ""

# Test 1: Verify deployment
echo "TEST 1: Verify All Pods Running"
echo "=========================================="
kubectl get pods -n $NAMESPACE -o wide
echo ""
echo "Expected: All pods should show STATUS: Running with READY: 1/1"
echo ""

# Test 2: Insert test data
echo "TEST 2: Insert Test Data"
echo "=========================================="
echo "Note: Ensure PostgreSQL port is forwarded first"
echo "kubectl port-forward -n $NAMESPACE svc/postgres-db 5432:5432"
echo ""
echo "Run this SQL:"
cat << 'EOF'
\c testdb

-- Insert test records
INSERT INTO public.customers (first_name, last_name, email, phone_number)
VALUES 
    ('John', 'Test', 'john.test@example.com', '555-0001'),
    ('Jane', 'Test', 'jane.test@example.com', '555-0002');

-- Verify insert
SELECT * FROM public.customers ORDER BY created_date DESC;
EOF
echo ""

# Test 3: Verify Kafka topics
echo "TEST 3: Verify Kafka Topics Created"
echo "=========================================="
echo "Command to list topics:"
echo "kubectl exec -it kafka-broker-0 -n $NAMESPACE -- kafka-topics --bootstrap-server localhost:9092 --list"
echo ""
echo "Expected topics:"
echo "  - postgresql.public.customers"
echo "  - dbhistory.postgres"
echo "  - connect-configs"
echo "  - connect-offsets"
echo "  - connect-status"
echo ""

# Test 4: Check Debezium connector
echo "TEST 4: Check Debezium Connector Status"
echo "=========================================="
echo "Port forward first:"
echo "kubectl port-forward -n $NAMESPACE svc/debezium-connect-lb 8083:8083"
echo ""
echo "Then run:"
echo "curl http://localhost:8083/connectors"
echo "curl http://localhost:8083/connectors/postgres-cdc-connector/status"
echo ""

# Test 5: Monitor Kafka messages
echo "TEST 5: Monitor Kafka Topic Messages"
echo "=========================================="
echo "Command:"
echo "kubectl exec -it kafka-broker-0 -n $NAMESPACE -- kafka-console-consumer \\\\"
echo "  --bootstrap-server localhost:9092 \\\\"
echo "  --topic postgresql.public.customers \\\\"
echo "  --from-beginning \\\\"
echo "  --property print.timestamp=true"
echo ""

# Test 6: Check RabbitMQ queue
echo "TEST 6: Monitor RabbitMQ"
echo "=========================================="
echo "Port forward:"
echo "kubectl port-forward -n $NAMESPACE svc/rabbitmq-lb 15672:15672 5672:5672"
echo ""
echo "Access Management UI:"
echo "URL: http://localhost:15672"
echo "Username: admin"
echo "Password: rabbitmq-securepass123"
echo ""
echo "Or use command to list queues:"
echo "kubectl exec rabbitmq-0 -n $NAMESPACE -- rabbitmqctl list_queues name messages consumers"
echo ""

# Test 7: Check consumer logs
echo "TEST 7: Monitor Consumer Logs"
echo "=========================================="
echo "Command:"
echo "kubectl logs -f deployment/cdc-consumer -n $NAMESPACE"
echo ""
echo "Expected output:"
echo "  [INFO] Received message: {...CDC event JSON...}"
echo "  [INFO] CDC Event - Operation: CREATE, Table: customers, ..."
echo ""

# Test 8: Update test
echo "TEST 8: Test UPDATE Operation"
echo "=========================================="
echo "SQL:"
cat << 'EOF'
UPDATE public.customers 
SET email = 'john.updated@example.com'
WHERE first_name = 'John' AND last_name = 'Test';

-- Verify update
SELECT * FROM public.customers WHERE first_name = 'John' AND last_name = 'Test';
EOF
echo ""
echo "Observe:"
echo "  - CDC event with 'op': 'u' (update)"
echo "  - Both 'before' and 'after' sections populated"
echo ""

# Test 9: Delete test
echo "TEST 9: Test DELETE Operation"
echo "=========================================="
echo "SQL:"
cat << 'EOF'
DELETE FROM public.customers 
WHERE first_name = 'Jane' AND last_name = 'Test';

-- Verify delete
SELECT COUNT(*) FROM public.customers;
EOF
echo ""
echo "Observe:"
echo "  - CDC event with 'op': 'd' (delete)"
echo "  - 'before' section contains deleted row data"
echo "  - 'after' section is null"
echo ""

# Test 10: Performance test
echo "TEST 10: Performance Testing"
echo "=========================================="
echo "Generate bulk inserts:"
cat << 'EOF'
-- Insert 1000 test records
INSERT INTO public.customers (first_name, last_name, email, phone_number)
SELECT 
    'Test' || i,
    'Customer' || i,
    'test' || i || '@example.com',
    '555-' || LPAD(i::text, 4, '0')
FROM generate_series(1, 1000) as i;

-- Check rows
SELECT COUNT(*) FROM public.customers;
EOF
echo ""
echo "Monitor:"
echo "  - Check Kafka messages: kafka-console-consumer (may take time)"
echo "  - Monitor consumer memory usage"
echo "  - Check consumer log for processing rate"
echo ""

# Additional monitoring commands
echo ""
echo "USEFUL MONITORING COMMANDS"
echo "=========================================="
echo ""
echo "1. Check PostgreSQL replication slot:"
echo "   kubectl exec postgres-db-0 -n $NAMESPACE -- psql -U postgres -d testdb -c 'SELECT * FROM pg_replication_slots;'"
echo ""
echo "2. Check PostgreSQL publication:"
echo "   kubectl exec postgres-db-0 -n $NAMESPACE -- psql -U postgres -d testdb -c 'SELECT * FROM pg_publication;'"
echo ""
echo "3. Check consumer pod events:"
echo "   kubectl describe pod -n $NAMESPACE -l app=cdc-consumer | grep -A 10 Events"
echo ""
echo "4. Watch pod status in real-time:"
echo "   kubectl get pods -n $NAMESPACE -w"
echo ""
echo "5. Check Kafka broker logs:"
echo "   kubectl logs kafka-broker-0 -n $NAMESPACE -f"
echo ""
echo "6. Check Debezium Connect logs:"
echo "   kubectl logs deployment/debezium-connect -n $NAMESPACE -f"
echo ""
echo "=========================================="
