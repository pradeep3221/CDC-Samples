# Consumer Application - Setup Guide

## Overview

The C# .NET consumer application processes CDC events from RabbitMQ and provides a framework for handling data changes.

## Architecture

```
RabbitMQ Queue → Consumer Application → Event Processing → Business Logic
```

## Building

```bash
cd consumer

# Restore dependencies
dotnet restore

# Build
dotnet build

# Publish for deployment
dotnet publish -c Release -o ./bin/Release/publish
```

## Docker Build

```bash
cd consumer

# Build Docker image
docker build -t cdc-consumer:latest -f Dockerfile .

# Push to registry
docker tag cdc-consumer:latest your-registry/cdc-consumer:latest
docker push your-registry/cdc-consumer:latest
```

## Configuration

### appsettings.json

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft": "Warning"
    }
  },
  "RabbitMq": {
    "HostName": "rabbitmq",
    "UserName": "admin",
    "Password": "rabbitmq-securepass123",
    "QueueName": "cdc.customers"
  }
}
```

### Environment Variables

```bash
# Override appsettings.json values
RabbitMq__HostName=rabbitmq.cdc-system.svc.cluster.local
RabbitMq__UserName=admin
RabbitMq__Password=rabbitmq-securepass123
RabbitMq__QueueName=cdc.customers
```

## Running Locally

```bash
cd consumer

# Run in development
dotnet run

# View output
# Timestamp Information Log shows CDC events being processed
```

## Running in Kubernetes

The consumer is deployed via Kubernetes deployment:

```bash
# Build and push image
docker build -t your-registry/cdc-consumer:latest .
docker push your-registry/cdc-consumer:latest

# Update image in k8s/cdc-consumer.yaml
# Deploy
kubectl apply -f k8s/cdc-consumer.yaml

# View logs
kubectl logs -f deployment/cdc-consumer -n cdc-system

# Scale replicas
kubectl scale deployment cdc-consumer --replicas=3 -n cdc-system
```

## CDC Message Format

### Example Message Structure

```json
{
  "schema": {
    "type": "struct",
    "fields": [...]
  },
  "payload": {
    "before": {
      "CustomerId": 1,
      "FirstName": "John",
      "LastName": "Doe",
      "Email": "john@example.com",
      "PhoneNumber": "555-0101"
    },
    "after": {
      "CustomerId": 1,
      "FirstName": "John",
      "LastName": "Doe",
      "Email": "john.doe@example.com",
      "PhoneNumber": "555-0101"
    },
    "source": {
      "version": 2,
      "connector": "sqlserver",
      "name": "mssql-server",
      "ts_ms": 1701234567890,
      "snapshot": "false",
      "db": "testdb",
      "schema": "dbo",
      "table": "Customers",
      "change_lsn": "00000000000000000001",
      "commit_lsn": "00000000000000000001"
    },
    "op": "u",
    "ts_ms": 1701234567890,
    "transaction": null
  }
}
```

### Operation Types

| Op | Meaning | Before | After |
|----|---------|--------|-------|
| c | Create | null | New values |
| r | Read | null | Current values |
| u | Update | Old values | New values |
| d | Delete | Old values | null |

## Extending the Consumer

### Add Custom Processing

```csharp
private void ProcessCustomerChange(Payload payload)
{
    if (payload.After != null)
    {
        // Handle INSERT/UPDATE
        var customer = payload.After;
        
        // Your business logic here
        if (payload.Op == "u")
        {
            // Log update
            _logger.LogInformation("Customer {Id} updated", customer.CustomerId);
        }
        else if (payload.Op == "c")
        {
            // Log create
            _logger.LogInformation("Customer {Id} created", customer.CustomerId);
        }
    }
    
    if (payload.Op == "d")
    {
        // Handle DELETE
        _logger.LogInformation("Customer deleted");
    }
}
```

### Persist to Database

```csharp
// Add DbContext for persistence
services.AddDbContext<AppDbContext>(opts =>
    opts.UseSqlServer(configuration.GetConnectionString("Default"))
);

// Process and persist
var context = serviceProvider.GetRequiredService<AppDbContext>();
var customer = new Customer { /* ... */ };
context.Customers.Add(customer);
await context.SaveChangesAsync();
```

### Send to API

```csharp
// Add HttpClient
services.AddHttpClient<IApiClient, ApiClient>();

// Call API
var client = serviceProvider.GetRequiredService<IApiClient>();
await client.PublishChangeAsync(cdcMessage);
```

## Health Checks

Add health check endpoint:

```csharp
services.AddHealthChecks()
    .AddRabbitMQ(new Uri($"amqp://{rabbitMqUser}:{rabbitMqPassword}@{hostName}"));

// In Program.cs
app.MapHealthChecks("/health");
```

## Performance Tuning

### Message Processing

```csharp
// Increase prefetch count for faster processing
await _channel.BasicQosAsync(prefetchSize: 0, prefetchCount: 10, global: false);
```

### Batch Processing

Accumulate messages and process in batches:

```csharp
var batch = new List<CdcMessage>();
const int batchSize = 100;

// Collect messages
if (batch.Count >= batchSize)
{
    await ProcessBatchAsync(batch);
    batch.Clear();
}
```

## Monitoring

### Metrics to Track

- Messages processed per second
- Processing latency
- Error rates
- Queue depth in RabbitMQ
- Consumer lag

### Enable Structured Logging

```csharp
services.AddLogging(builder =>
{
    builder.AddConsole();
    builder.AddEventSourceLogger();
    // Add Application Insights, Datadog, etc.
});
```

## Troubleshooting

### Connection Issues

```
ERROR: Failed to connect to rabbitmq
```

Solution: Verify hostname and credentials in appsettings.json

### Message Processing Errors

```
ERROR: Error processing message
```

Solution: Check message format, verify SQL Server CDC is emitting valid JSON

### Message Acknowledgment Timeout

Increase timeout in RabbitMQ and consumer configuration

## Reference

- [RabbitMQ .NET Client](https://www.rabbitmq.com/dotnet-api-guide.html)
- [.NET Configuration](https://learn.microsoft.com/dotnet/core/extensions/configuration)
- [Async/Await Best Practices](https://learn.microsoft.com/archive/msdn-magazine/2013/march/async-await-best-practices-in-asynchronous-programming)
