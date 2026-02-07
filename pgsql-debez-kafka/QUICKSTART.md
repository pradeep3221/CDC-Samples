# PostgreSQL CDC to Kafka - Quick Start

Get up and running in 5 minutes with Docker Compose.

## Prerequisites

- Docker & Docker Compose
- curl (for API calls)
- psql (optional, for direct database access)

## Step 1: Start Services (2 minutes)

```bash
cd docker
docker-compose up -d

# Verify all services are running
docker-compose ps
```

Expected output should show:
- zookeeper
- kafka
- postgres-db
- debezium-connect
- rabbitmq

## Step 2: Initialize PostgreSQL CDC (1 minute)

```bash
# Run from root directory of the project
cd debezium

# Initialize CDC
docker exec -i postgres-db psql -U postgres -d testdb -f init-cdc.sql
```

This script:
- Enables logical replication
- Creates a test table (Customers)
- Inserts sample data
- Sets up replication slot and publication

## Step 3: Create Debezium Connector (1 minute)

```bash
# Create the PostgreSQL CDC connector
curl -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  -d @connector-config.json

# Verify connector status
curl http://localhost:8083/connectors/postgres-cdc-connector/status
```

Expected response shows status: "RUNNING"

## Step 4: Verify Kafka Topic (30 seconds)

```bash
# List Kafka topics
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list

# Monitor the Customers topic
docker exec kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic postgresql.public.customers \
  --from-beginning
```

You should see the sample customer records as JSON.

## Step 5: Test with Consumer App (1 minute)

### Option A: Using Docker

```bash
# Build consumer image
docker build -t cdc-consumer:latest consumer/

# Run consumer
docker run -e "RabbitMq__HostName=rabbitmq" \
           -e "RabbitMq__UserName=admin" \
           -e "RabbitMq__Password=rabbitmq-securepass123" \
           --network docker_cdc-network \
           cdc-consumer:latest
```

### Option B: Using .NET CLI

```bash
cd consumer

# Build consumer
dotnet build

# Run consumer
dotnet run
```

## Step 6: Generate Test Data

Insert new records to see CDC in action:

```bash
# Connect to PostgreSQL
docker exec -it postgres-db psql -U postgres -d testdb

# Insert a new customer
INSERT INTO public.customers (first_name, last_name, email, phone_number)
VALUES ('Alice', 'Johnson', 'alice@example.com', '555-0101');

# Or insert multiple records
INSERT INTO public.customers (first_name, last_name, email, phone_number)
VALUES 
  ('Bob', 'Smith', 'bob@example.com', '555-0102'),
  ('Carol', 'White', 'carol@example.com', '555-0103');
```

Watch the consumer app output - you should see the new CDC events being processed!

## Verify Everything Works

Check each component:

```bash
# PostgreSQL
docker exec postgres-db psql -U postgres -d testdb \
  -c "SELECT * FROM public.customers;"

# Kafka topics
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list

# RabbitMQ (Management UI)
# Open http://localhost:15672 (admin / rabbitmq-securepass123)

# Debezium connector status
curl http://localhost:8083/connectors/postgres-cdc-connector/status | jq

# Consumer logs
docker-compose logs consumer
```

## Access URLs

| Service | URL | Credentials |
|---------|-----|-------------|
| PostgreSQL | localhost:5432 | postgres / postgres-password |
| Kafka | localhost:9092 | N/A |
| Zookeeper | localhost:2181 | N/A |
| Debezium Connect | http://localhost:8083 | N/A |
| RabbitMQ Management | http://localhost:15672 | admin / rabbitmq-securepass123 |

## Common Commands

### Database Operations
```bash
# Connect to PostgreSQL
docker exec -it postgres-db psql -U postgres -d testdb

# View CDC enabled tables
docker exec postgres-db psql -U postgres -d testdb \
  -c "SELECT * FROM pg_publication_tables;"

# Check replication slots
docker exec postgres-db psql -U postgres -d testdb \
  -c "SELECT * FROM pg_replication_slots;"
```

### Kafka Operations
```bash
# List all topics
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list

# View topic details
docker exec kafka kafka-topics --bootstrap-server localhost:9092 \
  --topic postgresql.public.customers --describe

# View topic messages
docker exec kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic postgresql.public.customers \
  --max-messages 5
```

### Debezium Operations
```bash
# List all connectors
curl http://localhost:8083/connectors

# Check connector status
curl http://localhost:8083/connectors/postgres-cdc-connector/status

# View connector configuration
curl http://localhost:8083/connectors/postgres-cdc-connector

# Delete connector
curl -X DELETE http://localhost:8083/connectors/postgres-cdc-connector
```

### Consumer Operations
```bash
# View consumer logs
docker-compose logs -f consumer

# Restart consumer
docker-compose restart consumer

# View RabbitMQ queues
docker exec rabbitmq rabbitmqctl list_queues
```

## Cleanup

```bash
# Stop all services
docker-compose down

# Remove volumes (includes all data)
docker-compose down -v

# Remove images
docker rmi cdc-consumer:latest
```

## Next Steps

- Read [README.md](./README.md) for full documentation
- Check [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) for system design
- Explore [docs/DEBEZIUM_SETUP.md](./docs/DEBEZIUM_SETUP.md) for advanced configuration
- Deploy to Kubernetes using [k8s](./k8s/) manifests

## Troubleshooting

### Services won't start
```bash
# Check logs
docker-compose logs

# Ensure ports are available
netstat -an | grep LISTEN | grep -E "5432|9092|8083|5672"
```

### Connector fails to start
```bash
# Check connector logs
curl http://localhost:8083/connectors/postgres-cdc-connector/status | jq '.tasks[].trace'

# Verify PostgreSQL is running
docker-compose exec postgres-db pg_isready
```

### No messages in Kafka
```bash
# Check Debezium logs
docker-compose logs debezium-connect

# Verify publication exists
docker exec postgres-db psql -U postgres -d testdb \
  -c "SELECT * FROM pg_publication WHERE pubname = 'dbz_publication';"
```

### Consumer not receiving messages
```bash
# Check RabbitMQ connection
docker-compose logs consumer | grep "RabbitMQ"

# Verify queue exists
docker exec rabbitmq rabbitmqctl list_queues
```




## Simple run
# Docker Compose (local testing)
cd docker
docker-compose up -d

# Initialize PostgreSQL CDC
cd ../debezium
docker exec -i postgres-db psql -U postgres -d testdb -f init-cdc.sql

# Create Debezium connector
curl -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  -d @connector-config.json

# Run consumer
cd ../consumer
dotnet run