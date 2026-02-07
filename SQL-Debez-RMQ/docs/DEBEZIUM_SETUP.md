# Debezium SQL Server Connector - Setup Guide

## Overview

This guide explains how to set up and configure the Debezium SQL Server CDC connector.

## Prerequisites

1. SQL Server with CDC enabled
2. Debezium Kafka Connect running
3. Kafka cluster accessible
4. SQL Server 2012+ or SQL Server Express

## Configuration

### Connector Configuration File

The connector is configured via JSON. See `connector-config.json` for the full configuration.

### Key Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `connector.class` | Debezium connector class | `io.debezium.connector.sqlserver.SqlServerConnector` |
| `database.hostname` | SQL Server hostname | `mssql-server.cdc-system.svc.cluster.local` |
| `database.port` | SQL Server port | `1433` |
| `database.user` | Database user | `sa` |
| `database.password` | Database password | `YourSecureP@ssw0rd!` |
| `database.dbname` | Database name | `testdb` |
| `database.enable.cdc` | Enable CDC mode | `true` |
| `snapshot.mode` | Snapshot strategy | `initial`, `never`, `when_needed` |
| `table.include.list` | Tables to capture (regex) | `dbo\..*` |
| `topic.prefix` | Topic name prefix | `sqlserver` |

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
curl http://localhost:8083/connectors/mssql-cdc-connector/status
```

### Method 2: ConfigMap + Kubernetes

The connector is deployed via Kubernetes ConfigMap. Update `k8s/configmap.yaml` and apply:

```bash
kubectl apply -f k8s/configmap.yaml
```

## Enable CDC on Tables

Run the provided script on SQL Server:

```sql
USE testdb;

-- Enable CDC on database
EXEC sys.sp_cdc_enable_db;

-- Enable CDC on table
EXEC sys.sp_cdc_enable_table
    @source_schema = 'dbo',
    @source_name = 'Customers',
    @role_name = NULL;
```

## Monitoring

### Check Connector Status

```bash
curl http://localhost:8083/connectors/mssql-cdc-connector/status | jq
```

### View Tasks

```bash
curl http://localhost:8083/connectors/mssql-cdc-connector/tasks | jq
```

### Monitor Topics

```bash
./kafka-console-consumer --bootstrap-server kafka:9092 \
  --topic sqlserver.dbo.Customers \
  --from-beginning
```

## Troubleshooting

### Connector Won't Start

1. Check logs: `kubectl logs deployment/debezium-connect -n cdc-system`
2. Verify database connectivity: `curl http://localhost:8083/connectors/mssql-cdc-connector/status`
3. Ensure CDC is enabled on database

### No Events Captured

1. Verify CDC is enabled: `SELECT is_cdc_enabled FROM sys.databases WHERE name='testdb'`
2. Check table CDC status: `SELECT * FROM cdc.change_tables`
3. Make changes to the table and verify changes are captured

### Performance Issues

1. Check `transforms` configuration
2. Increase `snapshot.batch.size` if handling large tables
3. Monitor Kafka broker performance
4. Check SQL Server transaction log usage

## Advanced Configuration

### Custom Transforms

```json
"transforms": "route,valuerouter",
"transforms.route.type": "org.apache.kafka.connect.transforms.RegexRouter",
"transforms.route.regex": "([^.]+)\\.([^.]+)\\.([^.]+)",
"transforms.route.replacement": "cdc.$3"
```

### History Topic Configuration

```json
"database.history.kafka.bootstrap.servers": "kafka:9092",
"database.history.kafka.topic": "dbhistory.mssql",
"database.history.skip.unparseable.ddl": true
```

## Scaling

For multiple tables or high-volume changes:

1. Deploy multiple Debezium instances with different `database.server.name`
2. Use consumer groups to parallelize consumption
3. Increase Kafka partitions for topics

## Reference

- [Debezium SQL Server Connector Documentation](https://debezium.io/documentation/reference/2.4/connectors/sqlserver.html)
- [SQL Server CDC Documentation](https://learn.microsoft.com/sql/relational-databases/track-changes/about-change-data-capture-sql-server)
