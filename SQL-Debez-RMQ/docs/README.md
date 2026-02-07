# CDC SQL Server to Debezium to RabbitMQ on Kubernetes

## Project Overview

This project implements a complete Change Data Capture (CDC) pipeline using:
- **SQL Server** as the source database with CDC enabled
- **Debezium** as the CDC platform for SQL Server
- **Kafka** as the event streaming platform (message broker)
- **RabbitMQ** as an alternative message broker for consumer applications
- **Kubernetes** for container orchestration
- **C# .NET** consumer application for processing CDC events

## Architecture

```
SQL Server (CDC Enabled)
        ↓
   Debezium
        ↓
   Kafka Cluster (Zookeeper + Kafka)
        ↓
   Kafka Topics
        ↓
   [Kafka-RabbitMQ Bridge] OR [Kafka Consumer]
        ↓
   RabbitMQ (Message Broker)
        ↓
   C# .NET Consumer Application
```

## Components

### 1. SQL Server
- **Image**: mcr.microsoft.com/mssql/server:2019-latest
- **CDC**: Enabled for automatic change capture
- **User**: sa (admin) / debezium (read-only for CDC)
- **Database**: testdb
- **Sample Table**: dbo.Customers

### 2. Kafka & Zookeeper
- **Zookeeper**: For Kafka cluster coordination
- **Kafka Broker**: Single broker for development (can scale to multiple brokers)
- **Topics**: Auto-created by Debezium for each table

### 3. Debezium Kafka Connect
- **Version**: 2.4
- **Connector**: SQL Server CDC Connector
- **Configuration**: JSON-based connector config
- **Features**:
  - Automatic topic creation
  - Change tracking setup
  - Transformation rules
  - History tracking

### 4. RabbitMQ
- **Image**: rabbitmq:3.12-management-alpine
- **Management UI**: Accessible on port 15672
- **Default Credentials**: admin/rabbitmq-securepass123
- **Queues**: CDC event queues created per table

### 5. C# .NET Consumer
- **.NET 10** runtime
- **Libraries**: RabbitMQ.Client, Newtonsoft.Json
- **Features**:
  - Async message consumption
  - CDC event parsing
  - Logging and monitoring
  - Error handling with negative acknowledgments

## Deployment

### Prerequisites
- Kubernetes cluster (1.20+)
- kubectl configured
- Container registry access (for custom images)
- At least 4GB RAM available

### Local Testing with Docker Compose

1. Navigate to docker directory:
   ```bash
   cd docker
   ```

2. Start services:
   ```bash
   docker-compose up -d
   ```

3. Wait for services to be healthy (30-60 seconds)

4. Access services:
   - Kafka: localhost:9092
   - Debezium Connect: http://localhost:8083
   - RabbitMQ Management: http://localhost:15672 (admin/rabbitmq-securepass123)
   - SQL Server: localhost,1433 (sa/YourSecureP@ssw0rd!)

### Kubernetes Deployment

1. **Prepare environment**:
   ```bash
   # Update secrets with your actual passwords
   kubectl apply -f k8s/namespace.yaml
   kubectl apply -f k8s/secrets.yaml
   ```

2. **Deploy core infrastructure**:
   ```bash
   # Zookeeper (required for Kafka)
   kubectl apply -f k8s/zookeeper.yaml
   
   # Wait for Zookeeper to be ready
   kubectl wait --for=condition=ready pod -l app=zookeeper -n cdc-system --timeout=300s
   
   # Kafka Broker
   kubectl apply -f k8s/kafka.yaml
   
   # Wait for Kafka to be ready
   kubectl wait --for=condition=ready pod -l app=kafka-broker -n cdc-system --timeout=300s
   ```

3. **Deploy data components**:
   ```bash
   # SQL Server
   kubectl apply -f k8s/mssql-server.yaml
   
   # RabbitMQ
   kubectl apply -f k8s/rabbitmq.yaml
   
   # Wait for both to be ready
   kubectl wait --for=condition=ready pod -l app=mssql-server,app=rabbitmq -n cdc-system --timeout=600s
   ```

4. **Initialize SQL Server CDC**:
   ```bash
   # Port forward to SQL Server
   kubectl port-forward -n cdc-system svc/mssql-server 1433:1433 &
   
   # Execute initialization script using sqlcmd or SQL Server Management Studio
   sqlcmd -S localhost,1433 -U sa -P 'YourSecureP@ssw0rd!' -i debezium/init-cdc.sql
   ```

5. **Deploy Debezium**:
   ```bash
   kubectl apply -f k8s/configmap.yaml
   kubectl apply -f k8s/debezium-connect.yaml
   
   # Wait for Debezium to be ready
   kubectl wait --for=condition=ready pod -l app=debezium-connect -n cdc-system --timeout=300s
   ```

6. **Deploy consumer**:
   ```bash
   # Build and push consumer Docker image
   cd consumer
   docker build -t your-registry/cdc-consumer:latest -f Dockerfile .
   docker push your-registry/cdc-consumer:latest
   
   # Update image reference in k8s/cdc-consumer.yaml
   # Then deploy:
   kubectl apply -f k8s/cdc-consumer.yaml
   ```

## Configuration

### Environment Variables

**SQL Server**:
```
ACCEPT_EULA=Y
SA_PASSWORD=YourSecureP@ssw0rd!
MSSQL_AGENT_ENABLED=true
MSSQL_PID=Express
```

**RabbitMQ**:
```
RABBITMQ_DEFAULT_USER=admin
RABBITMQ_DEFAULT_PASS=rabbitmq-securepass123
```

**Consumer**:
```
RabbitMq__HostName=rabbitmq.cdc-system.svc.cluster.local
RabbitMq__UserName=admin
RabbitMq__Password=rabbitmq-securepass123
RabbitMq__QueueName=cdc.customers
```

### Debezium Connector Configuration

Key settings in `k8s/configmap.yaml`:
- **database.hostname**: SQL Server service DNS
- **database.dbname**: Target database name
- **database.enable.cdc**: Enable CDC mode
- **snapshot.mode**: Initial snapshot strategy
- **table.include.list**: Tables to capture (regex pattern)
- **transforms**: Topic naming transformation

## Monitoring

### View Pod Status
```bash
kubectl get pods -n cdc-system
kubectl describe pod <pod-name> -n cdc-system
```

### View Logs
```bash
# Debezium logs
kubectl logs -f deployment/debezium-connect -n cdc-system

# Consumer logs
kubectl logs -f deployment/cdc-consumer -n cdc-system

# SQL Server logs
kubectl logs -f statefulset/mssql-server -n cdc-system
```

### Check Services
```bash
kubectl get svc -n cdc-system
kubectl get events -n cdc-system
```

### RabbitMQ Management
Access at http://localhost:15672 after port-forward:
```bash
kubectl port-forward -n cdc-system svc/rabbitmq-lb 15672:15672
```

## Troubleshooting

### SQL Server Not Connecting
1. Verify SQL Server pod is running: `kubectl get pods -n cdc-system | grep mssql`
2. Check SQL Server logs: `kubectl logs -f statefulset/mssql-server -n cdc-system`
3. Verify initialization script was executed
4. Check CDC is enabled: `SELECT name FROM sys.databases WHERE is_cdc_enabled = 1;`

### Debezium Not Capturing Changes
1. Check connector status:
   ```bash
   kubectl port-forward -n cdc-system svc/debezium-connect-lb 8083:8083
   curl http://localhost:8083/connectors/mssql-cdc-connector/status
   ```

2. Verify CDC is enabled on table:
   ```sql
   SELECT name FROM cdc.change_tables;
   ```

3. Check Debezium logs for errors

### Consumer Not Receiving Messages
1. Verify RabbitMQ queue exists and has messages
2. Check consumer logs for connection errors
3. Verify RabbitMQ credentials in environment variables
4. Check firewall rules if using external access

## Testing

### Insert Test Data
```sql
USE testdb;

INSERT INTO dbo.Customers (FirstName, LastName, Email, PhoneNumber)
VALUES ('Test', 'User', 'test@example.com', '555-0001');

-- Update test
UPDATE dbo.Customers SET Email = 'test.updated@example.com' WHERE CustomerId = 4;

-- Delete test
DELETE FROM dbo.Customers WHERE CustomerId = 4;
```

### Monitor Kafka Topics
```bash
# List topics
kafka-topics --bootstrap-server kafka-broker.cdc-system.svc.cluster.local:9092 --list

# Monitor topic content
kafka-console-consumer --bootstrap-server kafka-broker.cdc-system.svc.cluster.local:9092 \
  --topic sqlserver.dbo.Customers --from-beginning
```

## Scaling

### Horizontal Scaling
- **Multiple Kafka Brokers**: Update replica count and broker IDs
- **Multiple Debezium Instances**: Scale deployment replicas
- **Multiple Consumers**: Deploy multiple consumer instances with different group IDs

### Vertical Scaling
- Update resource requests/limits in YAML manifests
- Monitor memory usage and adjust accordingly

## Security Considerations

1. **Change Credentials**: Update passwords in secrets.yaml
2. **Use TLS**: Add TLS configuration for Kafka and RabbitMQ
3. **Network Policies**: Implement Kubernetes network policies
4. **RBAC**: Set up RBAC for service accounts
5. **Secret Management**: Use external secret management tools (Vault, etc.)

## Next Steps

1. Customize table inclusion/exclusion patterns
2. Add data transformation logic in consumer
3. Implement persistent storage for CDC state
4. Set up monitoring and alerting
5. Add authentication/authorization
6. Implement batch processing or aggregation
7. Add API layer for consuming CDC events

## References

- [Debezium Documentation](https://debezium.io/)
- [SQL Server CDC](https://learn.microsoft.com/sql/relational-databases/track-changes/about-change-data-capture-sql-server)
- [Kafka Documentation](https://kafka.apache.org/documentation/)
- [RabbitMQ Documentation](https://www.rabbitmq.com/documentation.html)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
