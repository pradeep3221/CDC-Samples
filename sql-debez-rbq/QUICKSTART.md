# SQL Server CDC to Debezium to RabbitMQ - Quick Start

## 1. Local Testing (Docker Compose)

```bash
# Navigate to docker directory
cd docker

# Start services
docker-compose up -d

# Wait 30-60 seconds for services to be healthy

# Verify services
docker ps | grep -E "(mssql|kafka|rabbitmq|debezium)"
```

## 2. Access Services

```bash
# SQL Server
# Host: localhost
# Port: 1433
# User: sa
# Password: YourSecureP@ssw0rd!

# Kafka
# Broker: localhost:9092

# Debezium Connect
# URL: http://localhost:8083

# RabbitMQ Management UI
# URL: http://localhost:15672
# User: admin
# Password: rabbitmq-securepass123
```

## 3. Initialize SQL Server CDC

```bash
# Option A: Using docker exec
docker exec -i mssql-server sqlcmd -U sa -P "YourSecureP@ssw0rd!" < debezium/init-cdc.sql

# Option B: Using SQL Server Management Studio or sqlcmd
sqlcmd -S localhost,1433 -U sa -P "YourSecureP@ssw0rd!" -i debezium/init-cdc.sql
```

## 4. Verify CDC Tables

```sql
-- Connect to SQL Server using your preferred tool
-- Server: localhost,1433
-- User: sa
-- Password: YourSecureP@ssw0rd!

-- Check if CDC is enabled
SELECT name FROM sys.databases WHERE is_cdc_enabled = 1;

-- Check CDC tables
SELECT name FROM cdc.change_tables;

-- View sample data
USE testdb;
SELECT * FROM dbo.Customers;
```

## 5. Create Debezium Connector

```bash
# Option A: Via REST API
curl -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  -d @debezium/connector-config.json

# Option B: Via Debezium UI
# Navigate to http://localhost:8083
```

## 6. Verify Kafka Topic

```bash
# List topics
docker exec kafka-broker kafka-topics \
  --bootstrap-server localhost:9092 \
  --list

# Monitor Kafka topic
docker exec kafka-broker kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic sqlserver.dbo.Customers \
  --from-beginning
```

## 7. Insert Test Data

```sql
USE testdb;

INSERT INTO dbo.Customers (FirstName, LastName, Email, PhoneNumber)
VALUES 
    ('Test', 'User', 'test@example.com', '555-0001'),
    ('Another', 'Customer', 'another@example.com', '555-0002');
```

## 8. Monitor RabbitMQ

```bash
# Access management UI
# http://localhost:15672
# User: admin
# Password: rabbitmq-securepass123

# Check queue via command line
docker exec rabbitmq rabbitmqctl list_queues name messages consumers
```

## 9. Run Consumer (C#)

```bash
# Build consumer
cd consumer
dotnet build

# Run consumer
dotnet run

# Or run via Docker
docker build -t cdc-consumer:local -f Dockerfile .
docker run -e RabbitMq__HostName=rabbitmq \
           -e RabbitMq__UserName=admin \
           -e RabbitMq__Password=rabbitmq-securepass123 \
           --network docker_default \
           cdc-consumer:local
```

## 10. Kubernetes Deployment

```bash
# Navigate to k8s directory
cd k8s

# Deploy all resources
bash ../docs/deploy.sh

# Or deploy manually
kubectl apply -f namespace.yaml
kubectl apply -f secrets.yaml
kubectl apply -f zookeeper.yaml
# ... wait for zookeeper ...
kubectl apply -f kafka.yaml
# ... wait for kafka ...
kubectl apply -f mssql-server.yaml
kubectl apply -f rabbitmq.yaml
# ... wait for both ...
kubectl apply -f configmap.yaml
kubectl apply -f debezium-connect.yaml

# Monitor deployment
kubectl get pods -n cdc-system -w
```

## Troubleshooting

### Services Won't Start
```bash
# Check logs
docker logs mssql-server
docker logs kafka-broker
docker logs debezium-connect

# Restart container
docker restart <service-name>
```

### CDC Not Capturing Changes
```sql
-- Verify CDC is enabled
SELECT is_cdc_enabled FROM sys.databases WHERE name='testdb';

-- Enable if needed
USE testdb;
EXEC sys.sp_cdc_enable_db;

-- Check CDC tables
SELECT * FROM cdc.change_tables;
```

### No Messages in Kafka
1. Verify Debezium connector is running
2. Check Debezium logs for errors
3. Verify table has CDC enabled
4. Insert test data after connector starts

### Consumer Not Receiving Messages
1. Verify RabbitMQ has messages in queue
2. Check consumer logs
3. Verify RabbitMQ credentials
4. Ensure consumer is running and connected

## Next Steps

1. Customize consumer logic in [Consumer.cs](./consumer/Services/RabbitMqConsumer.cs)
2. Add database persistence layer
3. Implement monitoring and alerting
4. Set up CI/CD pipeline
5. Configure SSL/TLS for production

## Documentation Files

- [README.md](./docs/README.md) - Complete documentation
- [ARCHITECTURE.md](./docs/ARCHITECTURE.md) - System architecture and design
- [DEBEZIUM_SETUP.md](./docs/DEBEZIUM_SETUP.md) - Debezium configuration
- [CONSUMER_SETUP.md](./docs/CONSUMER_SETUP.md) - Consumer application guide
- [TESTING.md](./docs/TESTING.md) - Testing and monitoring guide
