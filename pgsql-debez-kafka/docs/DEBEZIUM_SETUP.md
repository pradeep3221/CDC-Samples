# Debezium PostgreSQL Connector - Setup Guide

## Overview

This guide explains how to set up and configure the Debezium PostgreSQL CDC connector.

## Prerequisites

1. PostgreSQL with logical replication enabled
2. Debezium Kafka Connect running
3. Kafka cluster accessible
4. PostgreSQL 10+

## Configuration

### Connector Configuration File

The connector is configured via JSON. See `connector-config.json` for the full configuration.

### Key Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `connector.class` | Debezium connector class | `io.debezium.connector.postgresql.PostgresConnector` |
| `database.hostname` | PostgreSQL hostname | `postgres-db.cdc-system.svc.cluster.local` |
| `database.port` | PostgreSQL port | `5432` |
| `database.user` | Database user | `postgres` |
| `database.password` | Database password | `postgres-password` |
| `database.dbname` | Database name | `testdb` |
| `plugin.name` | Logical decoding plugin | `pgoutput` |
| `publication.name` | Publication name | `dbz_publication` |
| `slot.name` | Replication slot name | `debezium_slot` |
| `snapshot.mode` | Snapshot strategy | `initial`, `never`, `when_needed` |
| `table.include.list` | Tables to capture (regex) | `public\..*` |
| `topic.prefix` | Topic name prefix | `postgresql` |

## Deployment Methods

### Method 1: REST API

```bash
# Port forward Debezium Connect
kubectl port-forward svc/debezium-connect-lb 8083:8083 &

# Create connector
curl -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  -d @connector-config.json

# Check status
curl http://localhost:8083/connectors/postgres-cdc-connector/status
```

### Method 2: ConfigMap + Kubernetes

The connector is deployed via Kubernetes ConfigMap. Update `k8s/configmap.yaml` and apply:

```bash
kubectl apply -f k8s/configmap.yaml
```

## Enable Logical Replication

PostgreSQL must be configured with logical replication:

```sql
-- Check current settings
SHOW wal_level;  -- Should be 'logical'
SHOW max_wal_senders;  -- Should be >= 10
SHOW max_replication_slots;  -- Should be >= 10

-- If not set, update postgresql.conf:
-- wal_level = logical
-- max_wal_senders = 10
-- max_replication_slots = 10
```

## Create Publication & Replication Slot

Run the initialization script:

```bash
# Docker Compose
docker exec -i postgres-db psql -U postgres -d testdb -f debezium/init-cdc.sql

# Kubernetes
kubectl exec -it postgres-db-0 -n cdc-system -- psql -U postgres -d testdb -f /init-cdc.sql
```

This script:
- Creates replication role (debezium)
- Creates publication for all tables
- Sets up proper permissions

## Verify Setup

### Check Publication

```sql
-- List all publications
SELECT * FROM pg_publication;

-- Check publication details
SELECT schemaname, tablename, pubname
FROM pg_publication_tables
WHERE pubname = 'dbz_publication';
```

### Check Replication Slot

```sql
-- List replication slots
SELECT * FROM pg_replication_slots 
WHERE slot_name = 'debezium_slot';

-- Check slot status
SELECT slot_name, slot_type, active, restart_lsn
FROM pg_replication_slots;
```

### Check Permissions

```sql
-- Verify debezium user exists
SELECT usename FROM pg_user 
WHERE usename = 'debezium';

-- Check privileges
\du debezium
```

## Monitoring

### Check Connector Status

```bash
curl http://localhost:8083/connectors/postgres-cdc-connector/status | jq
```

### View Tasks

```bash
curl http://localhost:8083/connectors/postgres-cdc-connector/tasks | jq
```

### Monitor Topics

```bash
# List topics
kubectl exec kafka-broker-0 -n cdc-system -- \
  kafka-topics --bootstrap-server localhost:9092 --list

# Monitor Customers topic
kubectl exec kafka-broker-0 -n cdc-system -- \
  kafka-console-consumer --bootstrap-server localhost:9092 \
  --topic postgresql.public.customers \
  --from-beginning
```

## Troubleshooting

### Issue: Replication slot not advancing

**Symptom**: Connector connects but no messages appear

**Solution**:
```sql
-- Check slot state
SELECT * FROM pg_replication_slots;

-- Drop old slot if needed
SELECT pg_drop_replication_slot('debezium_slot');

-- Recreate via connector
```

### Issue: Permission denied

**Symptom**: "Permission denied for schema public"

**Solution**:
```sql
-- Grant proper permissions
GRANT CONNECT ON DATABASE testdb TO debezium;
GRANT USAGE ON SCHEMA public TO debezium;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO debezium;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO debezium;
```

### Issue: Connector fails to start

**Symptom**: Connector status shows error

**Check**:
```bash
# View connector logs
kubectl logs deployment/debezium-connect -n cdc-system --tail=50

# Check connectivity
kubectl exec postgres-db-0 -n cdc-system -- \
  psql -h postgres-db -U postgres -d testdb -c "SELECT 1;"
```

### Issue: No messages after insert

**Symptom**: Data inserted but no events appear

**Check**:
```sql
-- Verify table is in publication
SELECT * FROM pg_publication_tables;

-- Check WAL level
SHOW wal_level;

-- Check replication slot status
SELECT * FROM pg_replication_slots;
```

## Configuration Tuning

### For High Volume Changes

```json
{
  "max.batch.size": 1024,
  "max.queue.size": 8192,
  "poll.interval.ms": 100,
  "slot.drop_on_stop": false,
  "slot.retention.ms": 3600000
}
```

### For Large Tables

```json
{
  "snapshot.mode": "never",
  "snapshot.delay.ms": 5000,
  "schema.refresh.mode": "columns_only"
}
```

## Advanced Topics

### Filtering Tables

Update `table.include.list` to include specific tables:

```json
{
  "table.include.list": "public\\.(customers|orders|products)"
}
```

### Column Filtering

```json
{
  "column.include.list": "public\\.customers\\.(id|name|email)"
}
```

### Custom Topic Names

```json
{
  "transforms": "route",
  "transforms.route.type": "org.apache.kafka.connect.transforms.RegexRouter",
  "transforms.route.regex": "([^.]+)\\.([^.]+)\\.([^.]+)",
  "transforms.route.replacement": "cdc_$3"
}
```

## Related Documentation

- [README.md](./README.md) - Overview
- [ARCHITECTURE.md](./ARCHITECTURE.md) - System design
- [CONSUMER_SETUP.md](./CONSUMER_SETUP.md) - Consumer app
- [TESTING.md](./TESTING.md) - Testing guide
