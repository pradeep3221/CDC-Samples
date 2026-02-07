# PostgreSQL Debezium to Kafka - Change Data Capture Solution

A complete Change Data Capture (CDC) solution using PostgreSQL with Debezium and Kafka, including a C# .NET consumer application that processes CDC events.

## Project Structure

```
pgsql-debez-kafka/
├── README.md                          # This file
├── QUICKSTART.md                      # Quick start guide
│
├── k8s/                               # Kubernetes manifests
│   ├── namespace.yaml                 # Create cdc-system namespace
│   ├── secrets.yaml                   # Database and service credentials
│   ├── configmap.yaml                 # Debezium connector configuration
│   ├── zookeeper.yaml                 # Zookeeper StatefulSet
│   ├── kafka.yaml                     # Kafka Broker StatefulSet
│   ├── postgres.yaml                  # PostgreSQL StatefulSet
│   ├── rabbitmq.yaml                  # RabbitMQ StatefulSet + Services
│   ├── debezium-connect.yaml          # Debezium Deployment + Services
│   └── cdc-consumer.yaml              # Consumer Application Deployment
│
├── docker/                            # Docker compose & Dockerfiles
│   ├── docker-compose.yaml            # Local development environment
│   ├── Dockerfile.debezium            # Custom Debezium image (optional)
│   └── .dockerignore
│
├── debezium/                          # Debezium configuration
│   ├── connector-config.json          # PostgreSQL connector configuration
│   ├── init-cdc.sql                   # PostgreSQL script to enable logical replication
│   └── README.md                      # Debezium setup guide
│
├── consumer/                          # C# .NET Consumer Application
│   ├── CdcConsumer.csproj             # Project file
│   ├── Program.cs                     # Entry point
│   ├── appsettings.json               # Configuration
│   ├── Dockerfile                     # Docker image
│   ├── .dockerignore
│   ├── Models/
│   │   └── CdcMessage.cs              # CDC event models
│   ├── Services/
│   │   └── RabbitMqConsumer.cs        # RabbitMQ consumer service
│   └── bin/
│       └── Release/
│           └── publish/               # Published artifacts
│
└── docs/                              # Documentation
    ├── README.md                      # Complete documentation
    ├── ARCHITECTURE.md                # System architecture & design
    ├── DEBEZIUM_SETUP.md              # Debezium configuration guide
    ├── CONSUMER_SETUP.md              # Consumer application guide
    ├── TESTING.md                     # Testing & monitoring guide
    ├── deploy.sh                      # Kubernetes deployment script
    ├── init-cdc.sh                    # PostgreSQL CDC initialization
    ├── quickstart.sh                  # Quick start helper commands
    ├── health-check.sh                # Health check script
    └── cleanup.sh                     # Resource cleanup script
```

## Key Features

- **PostgreSQL CDC**: Uses PostgreSQL logical replication for change capture
- **Debezium Integration**: Captures database changes at source
- **Kafka Streaming**: Distributes events across topics
- **RabbitMQ Consumer**: Optional bridge for consuming via RabbitMQ
- **Docker Support**: Complete docker-compose for local development
- **Kubernetes Ready**: Full K8s manifests for production deployment
- **C# Consumer**: .NET application for processing CDC events

## Prerequisites

### Local Development
- Docker & Docker Compose
- PostgreSQL 12+ (provided by Docker)
- Kafka (provided by Docker)
- .NET 10 SDK (for building consumer app)

### Kubernetes Deployment
- Kubernetes 1.20+
- kubectl
- Helm (optional)

## Quick Start

### Local Development (Docker Compose)

```bash
# Navigate to docker directory
cd docker

# Start all services
docker-compose up -d

# Wait for services to be healthy (30-60 seconds)
docker-compose ps

# Initialize CDC
cd ../debezium
docker exec -i postgres-db psql -U postgres -d testdb -f init-cdc.sql

# Create Debezium connector
curl -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  -d @connector-config.json

# Start consumer (in consumer directory)
cd ../consumer
dotnet run
```

## Architecture

### Components

1. **PostgreSQL**: Source database with logical replication enabled
2. **Zookeeper**: Kafka coordination
3. **Kafka**: Event streaming platform
4. **Debezium Connect**: CDC capture engine
5. **RabbitMQ**: Optional message broker
6. **Consumer App**: Processes CDC events

### Data Flow

```
PostgreSQL (CDC) → Debezium → Kafka Topics → Consumer App
                         ↓
                     RabbitMQ (optional)
```

## Configuration

### PostgreSQL Connection
- Host: localhost (docker-compose) or postgres.cdc-system (k8s)
- Port: 5432
- User: postgres
- Password: postgres-password
- Database: testdb

### Kafka
- Bootstrap Server: localhost:9092 (docker-compose) or kafka:9092 (k8s)
- Zookeeper: localhost:2181 (docker-compose) or zookeeper:2181 (k8s)

### RabbitMQ
- Host: localhost (docker-compose) or rabbitmq (k8s)
- Port: 5672 (AMQP), 15672 (Management)
- User: admin
- Password: rabbitmq-securepass123

### Debezium
- Connector Class: PostgreSQL Connector
- Replication Slot: debezium_slot
- Publication Name: dbz_publication

## Documentation

- [QUICKSTART.md](./QUICKSTART.md) - Get started in 5 minutes
- [docs/README.md](./docs/README.md) - Complete setup guide
- [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) - System design
- [docs/DEBEZIUM_SETUP.md](./docs/DEBEZIUM_SETUP.md) - Debezium configuration
- [docs/CONSUMER_SETUP.md](./docs/CONSUMER_SETUP.md) - Consumer app development
- [docs/TESTING.md](./docs/TESTING.md) - Testing & monitoring

## Deployment

### Docker Compose (Local)
```bash
cd docker
docker-compose up -d
```

### Kubernetes
```bash
cd k8s
kubectl apply -f namespace.yaml
kubectl apply -f secrets.yaml
kubectl apply -f configmap.yaml
kubectl apply -f ./*.yaml
```

### Automated Deployment
```bash
./docs/deploy.sh
```

## Monitoring

### Check Services
```bash
# Docker Compose
docker-compose ps

# Kubernetes
kubectl get pods -n cdc-system
kubectl get svc -n cdc-system
```

### View Logs
```bash
# Docker Compose
docker-compose logs -f debezium-connect
docker-compose logs -f consumer

# Kubernetes
kubectl logs -n cdc-system -f deployment/debezium-connect
kubectl logs -n cdc-system -f deployment/cdc-consumer
```

### Monitor Kafka Topics
```bash
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list
docker exec kafka kafka-console-consumer --bootstrap-server localhost:9092 \
  --topic postgresql.public.customers --from-beginning
```

## Cleanup

### Docker Compose
```bash
cd docker
docker-compose down -v
```

### Kubernetes
```bash
./docs/cleanup.sh
```

## Troubleshooting

### PostgreSQL Connection Issues
- Verify credentials in appsettings.json
- Check PostgreSQL logs: `docker-compose logs postgres-db`
- Ensure logical replication is enabled: Check init-cdc.sql

### Debezium Connect Issues
- Check connector status: `curl http://localhost:8083/connectors/postgres-cdc-connector/status`
- View connector logs: `docker-compose logs debezium-connect`
- Verify database permissions and CDC configuration

### Consumer App Issues
- Check RabbitMQ connection: `docker-compose logs consumer`
- Verify message queue exists: `docker-compose exec rabbitmq rabbitmqctl list_queues`
- Check Kafka topics: `docker exec kafka kafka-topics --list --bootstrap-server localhost:9092`

## Contributing

Contributions are welcome! Please create an issue or pull request for bug fixes and enhancements.

## License

This project is provided as-is for educational and development purposes.
