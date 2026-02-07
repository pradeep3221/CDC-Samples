#!/bin/bash

# Testing and Monitoring Guide
# Common testing scenarios and monitoring commands

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
echo "Note: Ensure SQL Server port is forwarded first"
echo "kubectl port-forward -n $NAMESPACE svc/mssql-server 1433:1433"
echo ""
echo "Run this SQL:"
cat << 'EOF'
USE testdb;
SET IDENTITY_INSERT dbo.Customers OFF;

INSERT INTO dbo.Customers (FirstName, LastName, Email, PhoneNumber)
VALUES 
    ('John', 'Test', 'john.test@example.com', '555-0001'),
    ('Jane', 'Test', 'jane.test@example.com', '555-0002');

-- Verify insert
SELECT * FROM dbo.Customers ORDER BY CreatedDate DESC;
EOF
echo ""

# Test 3: Verify Kafka topics
echo "TEST 3: Verify Kafka Topics Created"
echo "=========================================="
echo "Command to list topics:"
echo "kubectl exec -it kafka-broker-0 -n $NAMESPACE -- kafka-topics --bootstrap-server localhost:9092 --list"
echo ""
echo "Expected topics:"
echo "  - sqlserver.dbo.Customers"
echo "  - dbhistory.mssql"
echo "  - connect-config"
echo "  - connect-offset"
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
echo "curl http://localhost:8083/connectors/mssql-cdc-connector/status"
echo ""

# Test 5: Monitor Kafka messages
echo "TEST 5: Monitor Kafka Topic Messages"
echo "=========================================="
echo "Command:"
echo "kubectl exec -it kafka-broker-0 -n $NAMESPACE -- kafka-console-consumer \\\\"
echo "  --bootstrap-server localhost:9092 \\\\"
echo "  --topic sqlserver.dbo.Customers \\\\"
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
echo "Or use AMQP client to monitor queue:"
echo "rabbitmqctl list_queues name messages consumers"
echo ""

# Test 7: Check consumer logs
echo "TEST 7: Monitor Consumer Logs"
echo "=========================================="
echo "Command:"
echo "kubectl logs -f deployment/cdc-consumer -n $NAMESPACE"
echo ""
echo "Expected output:"
echo "  [INFO] Received message: {...CDC event JSON...}"
echo "  [INFO] CDC Event - Operation: CREATE, Table: dbo.Customers, ..."
echo ""

# Test 8: Update test
echo "TEST 8: Test UPDATE Operation"
echo "=========================================="
echo "SQL:"
cat << 'EOF'
USE testdb;
UPDATE dbo.Customers 
SET Email = 'john.updated@example.com'
WHERE FirstName = 'John' AND LastName = 'Test';

-- Verify update
SELECT * FROM dbo.Customers WHERE FirstName = 'John' AND LastName = 'Test';
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
USE testdb;
DELETE FROM dbo.Customers 
WHERE FirstName = 'Jane' AND LastName = 'Test';

-- Verify delete
SELECT COUNT(*) FROM dbo.Customers;
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
USE testdb;
DECLARE @i INT = 0;
WHILE @i < 1000
BEGIN
    INSERT INTO dbo.Customers (FirstName, LastName, Email, PhoneNumber)
    VALUES ('Perf', 'Test' + CAST(@i AS NVARCHAR(10)), 'perf' + CAST(@i AS NVARCHAR(10)) + '@example.com', '555-' + RIGHT('0000' + CAST(@i AS NVARCHAR(10)), 4));
    SET @i = @i + 1;
END
EOF
echo ""
echo "Monitor:"
echo "  - Consumer throughput (messages/sec)"
echo "  - Latency from change to consumer"
echo "  - RabbitMQ queue depths"
echo "  - Kafka lag"
echo ""

# Test 11: Monitoring commands summary
echo "TEST 11: Useful Monitoring Commands"
echo "=========================================="
cat << 'EOF'
# Pod status
kubectl get pods -n cdc-system -w

# Pod logs
kubectl logs -f <pod-name> -n cdc-system

# Pod details
kubectl describe pod <pod-name> -n cdc-system

# Check disk usage
kubectl exec <pod-name> -n cdc-system -- df -h

# Check memory/CPU
kubectl top pods -n cdc-system

# Check events
kubectl get events -n cdc-system --sort-by='.lastTimestamp'

# Port forwarding
kubectl port-forward svc/<service> <local-port>:<service-port> -n cdc-system

# Exec into pod
kubectl exec -it <pod-name> -n cdc-system -- bash

# Check PVC usage
kubectl get pvc -n cdc-system
kubectl describe pvc <pvc-name> -n cdc-system
EOF
echo ""

# Test 12: Common issues and solutions
echo "TEST 12: Troubleshooting Common Issues"
echo "=========================================="
cat << 'EOF'
ISSUE: Debezium connector won't start
SOLUTION:
  1. Check connector logs: kubectl logs deployment/debezium-connect -n cdc-system
  2. Verify SQL Server is accessible
  3. Verify CDC is enabled on database
  4. Check Kafka connectivity

ISSUE: No messages in RabbitMQ queue
SOLUTION:
  1. Verify messages exist in Kafka topic
  2. Check bridge/consumer logs
  3. Verify RabbitMQ credentials
  4. Ensure queue name matches configuration

ISSUE: Consumer crashes on message
SOLUTION:
  1. Check message format in Kafka topic
  2. Review consumer code for parsing errors
  3. Check logs for detailed error messages
  4. Use negative acknowledgment to retry

ISSUE: High latency in CDC
SOLUTION:
  1. Increase Debezium snapshot batch size
  2. Reduce Kafka consumer fetch interval
  3. Increase consumer prefetch count
  4. Monitor and scale resources

ISSUE: SQL Server disk full
SOLUTION:
  1. Increase PVC size in Kubernetes
  2. Enable transaction log truncation
  3. Archive old CDC data
  4. Monitor growth rate
EOF
echo ""

echo "=========================================="
echo "End of Testing & Monitoring Guide"
echo "=========================================="
