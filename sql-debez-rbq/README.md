# Project Structure

```
SQL-Debez/
├── README.md                          # This file
├── QUICKSTART.md                      # Quick start guide
│
├── k8s/                               # Kubernetes manifests
│   ├── namespace.yaml                 # Create cdc-system namespace
│   ├── secrets.yaml                   # Database and service credentials
│   ├── configmap.yaml                 # Debezium connector configuration
│   ├── zookeeper.yaml                 # Zookeeper StatefulSet
│   ├── kafka.yaml                     # Kafka Broker StatefulSet
│   ├── mssql-server.yaml              # SQL Server StatefulSet
│   ├── rabbitmq.yaml                  # RabbitMQ StatefulSet + Services
│   ├── debezium-connect.yaml          # Debezium Deployment + Services
│   └── cdc-consumer.yaml              # Consumer Application Deployment
│
├── docker/                            # Docker compose & Dockerfiles
│   ├── docker-compose.yaml            # Local development environment
│   ├── Dockerfile.debezium            # Custom Debezium image (optional)
│   ├── Dockerfile.consumer            # Consumer app image
│   └── .dockerignore
│
├── debezium/                          # Debezium configuration
│   ├── connector-config.json          # SQL Server connector configuration
│   ├── init-cdc.sql                   # SQL script to enable CDC
│   └── README.md                      # Debezium setup guide
│
├── consumer/                          # C# .NET Consumer Application
│   ├── CdcConsumer.csproj             # Project file
│   ├── Program.cs                     # Entry point
│   ├── appsettings.json               # Configuration
│   ├── appsettings.bridge.json        # Bridge configuration
│   ├── Dockerfile                     # Docker image
│   ├── .dockerignore
│   ├── Models/
│   │   └── CdcMessage.cs              # CDC event models
│   ├── Services/
│   │   ├── RabbitMqConsumer.cs        # RabbitMQ consumer service
│   │   └── KafkaRabbitMqBridge.cs     # Kafka to RabbitMQ bridge
│   └── bin/
│       └── Release/
│           └── publish/               # Published artifacts
│
└── docs/                              # Documentation
    ├── README.md                      # Complete documentation
    ├── ARCHITECTURE.md                # System architecture & design
    ├── DEBEZIUM_SETUP.md              # Debezium configuration guide
    ├── CONSUMER_SETUP.md              # Consumer application guide
    ├── TESTING.md                      # Testing & monitoring guide
    ├── deploy.sh                      # Kubernetes deployment script
    ├── init-cdc.sh                    # SQL Server CDC initialization
    ├── quickstart.sh                  # Quick start helper commands
    ├── health-check.sh                # Health check script
    └── cleanup.sh                     # Resource cleanup script
```

## File Descriptions

### Kubernetes Manifests (k8s/)
- **namespace.yaml**: Creates the cdc-system namespace for all resources
- **secrets.yaml**: Stores credentials for SQL Server, RabbitMQ, and Debezium
- **configmap.yaml**: Debezium connector configuration for SQL Server CDC
- **zookeeper.yaml**: Zookeeper cluster for Kafka coordination
- **kafka.yaml**: Kafka broker cluster for event streaming
- **mssql-server.yaml**: SQL Server database with PVC for data persistence
- **rabbitmq.yaml**: RabbitMQ message broker with management UI
- **debezium-connect.yaml**: Debezium Kafka Connect deployment
- **cdc-consumer.yaml**: C# consumer application for processing changes

### Docker Setup (docker/)
- **docker-compose.yaml**: Complete local development stack
- **Dockerfile.debezium**: Custom Debezium image with additional plugins
- Runs on Docker/Podman without Kubernetes

### Debezium Configuration (debezium/)
- **connector-config.json**: SQL Server connector configuration
- **init-cdc.sql**: T-SQL script to enable CDC on database and tables
- Creates test data and necessary permissions

### Consumer Application (consumer/)
- **CdcConsumer.csproj**: .NET 10 project with dependencies
- **Program.cs**: Application entry point with DI configuration
- **Models/**: CDC event data models
- **Services/**: RabbitMQ consumer and Kafka bridge implementations
- **appsettings.json**: RabbitMQ connection settings
- **Dockerfile**: Multi-stage build for container deployment

### Documentation (docs/)
- **README.md**: Complete setup, deployment, and troubleshooting guide
- **ARCHITECTURE.md**: System design, data flow, and component interactions
- **DEBEZIUM_SETUP.md**: Detailed Debezium connector configuration
- **CONSUMER_SETUP.md**: Consumer application development and extension
- **TESTING.md**: Testing procedures and monitoring commands
- **deploy.sh**: Automated Kubernetes deployment script
- **health-check.sh**: Verify all components are running correctly
- **quickstart.sh**: Helper commands for common operations
- **cleanup.sh**: Remove all resources from Kubernetes cluster

## Key Technologies

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| Source DB | SQL Server | 2019+ | Data source with CDC |
| CDC | Debezium | 2.4 | Change Data Capture |
| Streaming | Apache Kafka | 7.5.0 | Event streaming |
| Coordination | Zookeeper | 7.5.0 | Kafka coordination |
| Message Queue | RabbitMQ | 3.12 | Final message broker |
| Consumer | .NET | 10.0 | Event processing |
| Orchestration | Kubernetes | 1.20+ | Container orchestration |

## Quick Commands

```bash
# Deploy to Kubernetes
cd k8s
bash ../docs/deploy.sh

# Local development with Docker Compose
cd docker
docker-compose up -d

# Access services
kubectl port-forward svc/sql-server 1433:1433 -n cdc-system
kubectl port-forward svc/debezium-connect-lb 8083:8083 -n cdc-system
kubectl port-forward svc/rabbitmq-lb 15672:15672 -n cdc-system

# View logs
kubectl logs -f deployment/cdc-consumer -n cdc-system

# Test CDC
# Insert data into SQL Server and monitor:
kubctl logs -f deployment/cdc-consumer -n cdc-system

# Clean up
bash docs/cleanup.sh
```

## Configuration

All sensitive data is stored in Kubernetes Secrets or environment variables:
- Database credentials in `secrets.yaml`
- RabbitMQ credentials in `secrets.yaml`
- Debezium configuration in `configmap.yaml`
- Consumer settings in `appsettings.json` or environment variables

Update credentials in production before deploying!

## Architecture Overview

```
SQL Server (CDC) → Debezium → Kafka → RabbitMQ → C# Consumer
```

See [ARCHITECTURE.md](docs/ARCHITECTURE.md) for detailed system design.

## Support

- See [QUICKSTART.md](QUICKSTART.md) for quick start steps
- See [README.md](docs/README.md) for complete documentation
- Check [TESTING.md](docs/TESTING.md) for monitoring and troubleshooting


## Next Steps
- Update passwords in secrets.yaml
- Initialize SQL Server CDC: Run init-cdc.sql
- Deploy to Kubernetes or run locally with Docker Compose
- Test with sample data insertions
- Monitor via RabbitMQ Management UI and consumer logs
- Customize consumer logic for your business requirements