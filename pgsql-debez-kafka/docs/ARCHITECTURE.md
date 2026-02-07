# CDC Pipeline - Architecture and Design (PostgreSQL)

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
│  │   PostgreSQL Database    │                                              │
│  │ (Logical Replication)    │                                              │
│  │                          │                                              │
│  │  - testdb                │                                              │
│  │  - public.customers      │                                              │
│  └───────────┬──────────────┘                                              │
│              │ (WAL Entries)                                               │
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
│  │  │  PostgreSQL Connector                                    │   │   │
│  │  │  - Monitors replication slot                            │   │   │
│  │  │  - Reads logical changes                                │   │   │
│  │  │  - Converts changes to events                          │   │   │
│  │  │  - Applies transformations                            │   │   │
│  │  └────────────────┬─────────────────────────────────────────┘   │   │
│  └───────────────────┼──────────────────────────────────────────────┘   │
│                      │ (CDC Events in JSON format)                       │
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
│    │  │  │  - postgresql.public.customers                      │ │  │  │
│    │  │  │  - dbhistory.postgres                               │ │  │  │
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
│    │    postgresql.public.customers → cdc.customers                 │  │
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
User inserts row in PostgreSQL
    ↓
PostgreSQL logs change in WAL
    ↓
Debezium reads from replication slot
    ↓
Create event generated
    ↓
Event published to Kafka topic (postgresql.public.customers)
    ↓
[Optional] Bridge consumes and publishes to RabbitMQ (cdc.customers)
    ↓
Consumer receives message
    ↓
Consumer processes and acknowledges message
```

### UPDATE Operation
```
User updates row in PostgreSQL
    ↓
PostgreSQL logs change in WAL
    ↓
Debezium reads from replication slot
    ↓
Update event with before and after values
    ↓
Event published to Kafka topic (postgresql.public.customers)
    ↓
[Optional] Bridge consumes and publishes to RabbitMQ (cdc.customers)
    ↓
Consumer receives message with before/after data
    ↓
Consumer processes and acknowledges message
```

### DELETE Operation
```
User deletes row in PostgreSQL
    ↓
PostgreSQL logs change in WAL
    ↓
Debezium reads from replication slot
    ↓
Delete event with before values
    ↓
Event published to Kafka topic (postgresql.public.customers)
    ↓
[Optional] Bridge consumes and publishes to RabbitMQ (cdc.customers)
    ↓
Consumer receives message
    ↓
Consumer processes and acknowledges message
```

## Components Interaction

### PostgreSQL ↔ Debezium
- **Protocol**: PostgreSQL replication protocol
- **Data**: Changes from replication slot via logical replication
- **Frequency**: Continuous or near-real-time

### Debezium ↔ Kafka
- **Protocol**: Kafka Protocol
- **Data**: Serialized change events (JSON)
- **Persistence**: Kafka retains messages per retention policy

### Kafka ↔ RabbitMQ Bridge
- **Protocol**: Kafka Consumer API + AMQP
- **Mapping**: Kafka topics → RabbitMQ queues
- **Reliability**: Message acknowledgments

## Key Concepts

### Logical Replication
PostgreSQL's logical replication feature streams database changes:
- Enabled via `wal_level = logical`
- Replication slots capture changes
- Publications determine which tables to replicate

### Debezium PostgreSQL Connector
- Uses `pgoutput` plugin for logical decoding
- Non-intrusive monitoring (no extra tables)
- Supports all table modifications

### Message Format
CDC events are JSON with structure:
```json
{
  "schema": { ... },
  "payload": {
    "op": "c|r|u|d",
    "ts_ms": 1234567890,
    "before": { ... },
    "after": { ... },
    "source": { ... },
    "txId": "123"
  }
}
```
