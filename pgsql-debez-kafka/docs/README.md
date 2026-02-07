# PostgreSQL Debezium to Kafka on Kubernetes

## Project Overview

This project implements a complete Change Data Capture (CDC) pipeline using:
- **PostgreSQL** as the source database with logical replication enabled
- **Debezium** as the CDC platform for PostgreSQL
- **Kafka** as the event streaming platform (message broker)
- **RabbitMQ** as an alternative message broker for consumer applications
- **Kubernetes** for container orchestration
- **C# .NET** consumer application for processing CDC events

## Architecture

```
PostgreSQL (Logical Replication)
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

### 1. PostgreSQL
- **Image**: postgres:15-alpine
- **Logical Replication**: Enabled (wal_level=logical)
- **User**: postgres (admin) / debezium (read-only for CDC)
- **Database**: testdb
- **Sample Table**: public.customers

### 2. Kafka & Zookeeper
- **Zookeeper**: For Kafka cluster coordination
- **Kafka Broker**: Single broker for development (can scale to multiple brokers)
- **Topics**: Auto-created by Debezium for each table

### 3. Debezium Kafka Connect
- **Version**: 2.4
- **Connector**: PostgreSQL CDC Connector
- **Configuration**: JSON-based connector config
- **Features**:
  - Logical replication support
  - Publication-based change tracking
  - Automatic topic creation
  - Transformation rules

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

## Installation & Setup

### Prerequisites
- Kubernetes cluster (1.20+) or Docker/Docker Compose
- kubectl configured (for K8s)
- Container registry access (for custom images)
- At least 4GB RAM available

### Local Testing with Docker Compose

```bash
cd docker
docker-compose up -d

# Wait for services to be healthy (30-60 seconds)
docker-compose ps

# Initialize PostgreSQL CDC
cd ../debezium
docker exec -i postgres-db psql -U postgres -d testdb -f init-cdc.sql

# Create Debezium connector
curl -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  -d @connector-config.json

# Verify connector status
curl http://localhost:8083/connectors/postgres-cdc-connector/status

# Start consumer
cd ../consumer
dotnet run
```

### Kubernetes Deployment

See [QUICKSTART.md](../QUICKSTART.md) for step-by-step guide.

## Configuration

### Environment Variables

**PostgreSQL**:
```
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres-password
POSTGRES_DB=testdb
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

## Monitoring & Troubleshooting

### Check Services
```bash
# Docker Compose
docker-compose ps

# Kubernetes
kubectl get pods -n cdc-system
```

### View Logs
```bash
# Debezium
docker-compose logs -f debezium-connect
kubectl logs -f deployment/debezium-connect -n cdc-system

# Consumer
docker-compose logs -f consumer
kubectl logs -f deployment/cdc-consumer -n cdc-system
```

### Monitor Kafka Topics
```bash
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list
docker exec kafka kafka-console-consumer --bootstrap-server localhost:9092 \
  --topic postgresql.public.customers --from-beginning
```

## Support & Documentation

- [QUICKSTART.md](../QUICKSTART.md)
- [ARCHITECTURE.md](./ARCHITECTURE.md)
- [DEBEZIUM_SETUP.md](./DEBEZIUM_SETUP.md)
- [CONSUMER_SETUP.md](./CONSUMER_SETUP.md)
- [TESTING.md](./TESTING.md)
