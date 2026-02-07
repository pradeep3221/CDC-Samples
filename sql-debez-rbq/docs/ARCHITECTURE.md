# CDC Pipeline - Architecture and Design

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Change Data Capture Pipeline                  │
└─────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────┐
│                            Data Source Layer                                 │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────────────────┐                                              │
│  │   SQL Server Database    │                                              │
│  │  (CDC Enabled Tables)    │                                              │
│  │                          │                                              │
│  │  - testdb                │                                              │
│  │  - dbo.Customers         │                                              │
│  └───────────┬──────────────┘                                              │
│              │ (Change Notifications)                                      │
│              └──────────────────────────────────────────┐                  │
│                                                         │                  │
└─────────────────────────────────────────────────────────┼──────────────────┘

┌──────────────────────────────────────────────────────────┼──────────────────┐
│                      Change Capture Layer                 │                   │
├──────────────────────────────────────────────────────────┼──────────────────┤
│                                                           │                   │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │              Debezium Kafka Connect Cluster                        │   │
│  │  ┌────────────────────────────────────────────────────────────┐   │   │
│  │  │  SQL Server CDC Connector                                │   │   │
│  │  │  - Monitors CDC tables                                  │   │   │
│  │  │  - Converts changes to events                          │   │   │
│  │  │  - Applies transformations                            │   │   │
│  │  └────────────────┬─────────────────────────────────────────┘   │   │
│  └───────────────────┼──────────────────────────────────────────────┘   │
│                      │ (CDC Events in Avro/JSON format)                  │
│                      │                                                   │
└──────────────────────┼───────────────────────────────────────────────────┘

┌──────────────────────┼───────────────────────────────────────────────────────┐
│               Event Streaming & Brokering Layer            │                   │
├──────────────────────┼───────────────────────────────────────────────────────┤
│                      │                                                       │
│    ┌─────────────────────────────────────────────────────────────────────┐  │
│    │              Apache Kafka Cluster                                  │  │
│    │  ┌──────────────────────┐                                         │  │
│    │  │  Zookeeper Ensemble  │  (Cluster Coordination)               │  │
│    │  │  - Broker management │                                         │  │
│    │  │  - Leader election   │                                         │  │
│    │  └──────────────────────┘                                         │  │
│    │                                                                    │  │
│    │  ┌────────────────────────────────────────────────────────────┐  │  │
│    │  │           Kafka Broker Node (Partition Leader)           │  │  │
│    │  │  ┌──────────────────────────────────────────────────────┐ │  │  │
│    │  │  │  Topics:                                            │ │  │  │
│    │  │  │  - sqlserver.dbo.Customers                         │ │  │  │
│    │  │  │  - dbhistory.mssql                                 │ │  │  │
│    │  │  │  - connect-configs                                 │ │  │  │
│    │  │  │  - connect-offsets                                 │ │  │  │
│    │  │  │  - connect-status                                  │ │  │  │
│    │  │  └──────────────────────────────────────────────────────┘ │  │  │
│    │  └────────────────────────────────────────────────────────────┘  │  │
│    └──────────┬───────────────────────────────────────────────────────┘  │
│               │ (Kafka Protocol)                                         │
└───────────────┼────────────────────────────────────────────────────────────┘

┌───────────────┼────────────────────────────────────────────────────────────┐
│               │         Message Queue & Distribution Layer                  │
├───────────────┼────────────────────────────────────────────────────────────┤
│               │                                                            │
│    ┌──────────────────────────────────────────────────────────────────┐  │
│    │  [Kafka → RabbitMQ Bridge Service] (Optional)                   │  │
│    │  - Consumes from Kafka topics                                   │  │
│    │  - Publishes to RabbitMQ queues                                │  │
│    │  - Topic to Queue mapping:                                      │  │
│    │    sqlserver.dbo.Customers → cdc.customers                     │  │
│    └────────────────┬─────────────────────────────────────────────────┘  │
│                     │                                                      │
│    ┌────────────────────────────────────────────────────────────────┐    │
│    │         RabbitMQ Message Broker Cluster                       │    │
│    │  ┌────────────────────────────────────────────────────────┐   │    │
│    │  │  Queues:                                              │   │    │
│    │  │  - cdc.customers (received changes)                  │   │    │
│    │  │  - dlq.customers (dead letter queue)                 │   │    │
│    │  │  - retry.customers (retry messages)                  │   │    │
│    │  │                                                       │   │    │
│    │  │  Consumers:                                           │   │    │
│    │  │  - cdc-consumer-app (subscribed, consumer group)    │   │    │
│    │  └────────────────────────────────────────────────────────┘   │    │
│    │                                                                │    │
│    │  Management UI: http://rabbitmq:15672                        │    │
│    └─────────────┬──────────────────────────────────────────────────┘    │
│                  │ (AMQP Protocol)                                        │
└──────────────────┼───────────────────────────────────────────────────────┘

┌──────────────────┼──────────────────────────────────────────────────────────┐
│                  │      Consumer & Processing Layer                          │
├──────────────────┼──────────────────────────────────────────────────────────┤
│                  │                                                          │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                  CDC Consumer Application (.NET)                     │ │
│  │  ┌────────────────────────────────────────────────────────────────┐ │ │
│  │  │  Message Handler                                             │ │ │
│  │  │  - Receives change events from RabbitMQ                     │ │ │
│  │  │  - Deserializes CDC payload                                │ │ │
│  │  │  - Identifies operation type (C/R/U/D)                     │ │ │
│  │  │  - Logs changes with context                               │ │ │
│  │  │  - Error handling with negative acknowledgment             │ │ │
│  │  └────────────────┬─────────────────────────────────────────────┘ │ │
│  │                   │                                                 │ │
│  │  ┌───────────────────────────────────────────────────────────────┐ │ │
│  │  │  Business Logic (Customizable)                              │ │ │
│  │  │  - Data validation                                          │ │ │
│  │  │  - Store in database                                        │ │ │
│  │  │  - Cache updates                                           │ │ │
│  │  │  - Call external APIs                                      │ │ │
│  │  │  - Send notifications                                      │ │ │
│  │  └───────────────────────────────────────────────────────────────┘ │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Data Flow

### INSERT Operation
```
User inserts row in SQL Server
    ↓
SQL Server CDC captures change
    ↓
Debezium reads from CDC log
    ↓
Create event generated
    ↓
Event published to Kafka topic (sqlserver.dbo.Customers)
    ↓
[Optional] Bridge consumes and publishes to RabbitMQ (cdc.customers)
    ↓
Consumer receives message
    ↓
Consumer processes and acknowledges message
```

### UPDATE Operation
```
User updates row in SQL Server
    ↓
SQL Server CDC captures before/after images
    ↓
Debezium reads from CDC log
    ↓
Update event with before and after values
    ↓
Event published to Kafka topic (sqlserver.dbo.Customers)
    ↓
[Optional] Bridge consumes and publishes to RabbitMQ (cdc.customers)
    ↓
Consumer receives message with before/after data
    ↓
Consumer processes and acknowledges message
```

### DELETE Operation
```
User deletes row in SQL Server
    ↓
SQL Server CDC captures deletion
    ↓
Debezium reads from CDC log
    ↓
Delete event with before values only
    ↓
Event published to Kafka topic (sqlserver.dbo.Customers)
    ↓
[Optional] Bridge consumes and publishes to RabbitMQ (cdc.customers)
    ↓
Consumer receives message
    ↓
Consumer processes and acknowledges message
```

## Components Interaction

### SQL Server ↔ Debezium
- **Protocol**: TDS (Tabular Data Stream) via SQL Server connection
- **Data**: CDC log changes from sys.fn_cdc_get_all_changes_*
- **Frequency**: Periodic polling (configurable)

### Debezium ↔ Kafka
- **Protocol**: Kafka Protocol
- **Data**: Serialized change events (Avro/JSON)
- **Persistence**: Kafka retains messages per retention policy

### Kafka ↔ RabbitMQ Bridge
- **Protocol**: Kafka Consumer API + AMQP
- **Mapping**: Kafka topics → RabbitMQ queues
- **Reliability**: Message acknowledgments

### RabbitMQ ↔ Consumer App
- **Protocol**: AMQP
- **Delivery**: Push model with async consumers
- **Acks**: Manual acknowledgment after processing

## Kubernetes Deployment Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                          │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │            cdc-system Namespace                         │ │
│  │                                                          │ │
│  │  ┌─────────────────────────────────────────────────┐   │ │
│  │  │ StatefulSet (Persistent Storage)                │   │ │
│  │  │ - zookeeper-0                                  │   │ │
│  │  │ - kafka-broker-0                               │   │ │
│  │  │ - mssql-server-0                               │   │ │
│  │  │ - rabbitmq-0                                   │   │ │
│  │  └─────────────────────────────────────────────────┘   │ │
│  │                                                          │ │
│  │  ┌─────────────────────────────────────────────────┐   │ │
│  │  │ Deployment (Stateless)                          │   │ │
│  │  │ - debezium-connect (replicas: 1)               │   │ │
│  │  │ - cdc-consumer (replicas: 1)                   │   │ │
│  │  └─────────────────────────────────────────────────┘   │ │
│  │                                                          │ │
│  │  ┌─────────────────────────────────────────────────┐   │ │
│  │  │ Services                                        │   │ │
│  │  │ - ClusterIP services (internal DNS)            │   │ │
│  │  │ - LoadBalancer services (external access)      │   │ │
│  │  └─────────────────────────────────────────────────┘   │ │
│  │                                                          │ │
│  │  ┌─────────────────────────────────────────────────┐   │ │
│  │  │ Storage (Persistent Volumes)                   │   │ │
│  │  │ - PVC for Zookeeper data/logs                  │   │ │
│  │  │ - PVC for Kafka data                           │   │ │
│  │  │ - PVC for SQL Server data                      │   │ │
│  │  │ - PVC for RabbitMQ data                        │   │ │
│  │  └─────────────────────────────────────────────────┘   │ │
│  │                                                          │ │
│  │  ┌─────────────────────────────────────────────────┐   │ │
│  │  │ ConfigMaps & Secrets                           │   │ │
│  │  │ - Debezium connector config                    │   │ │
│  │  │ - Database credentials                         │   │ │
│  │  │ - RabbitMQ credentials                         │   │ │
│  │  └─────────────────────────────────────────────────┘   │ │
│  └──────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────┘
```

## Key Design Decisions

### Why Kafka Between Debezium and RabbitMQ?
- **High throughput**: Handles large volumes of changes
- **Persistence**: Retains messages for replay/recovery
- **Decoupling**: Debezium and consumers are independent
- **Scalability**: Easy to add more consumers

### Why RabbitMQ as Final Broker?
- **Flexible routing**: Topic-based and direct exchanges
- **Reliability features**: Dead letter queues, redelivery
- **Management UI**: Built-in monitoring
- **Wide support**: Works with many client libraries

### Why .NET Consumer?
- **Strong typing**: Compile-time error checking
- **Performance**: Native compilation capability
- **Integration**: Works with SQL Server, Azure services
- **Async/await**: Efficient async message processing

## Scaling Considerations

### Horizontal Scaling
- **Debezium**: Deploy multiple instances with different server IDs
- **Kafka**: Add broker nodes to the cluster
- **Consumers**: Scale replicas with consumer groups
- **RabbitMQ**: Use RabbitMQ clustering for HA

### Vertical Scaling
- Increase CPU/memory limits in Kubernetes
- Monitor actual usage and adjust accordingly

### Performance Tuning
- Kafka: Adjust batch size, compression, replication factor
- Debezium: Tune snapshot batch size, LSN polling intervals
- Consumer: Batch processing, prefetch count, thread pool size
