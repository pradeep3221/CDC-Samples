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
      "customer_id": 1,
      "first_name": "John",
      "last_name": "Doe",
      "email": "john@example.com",
      "phone_number": "555-0101"
    },
    "after": {
      "customer_id": 1,
      "first_name": "John",
      "last_name": "Doe",
      "email": "john.doe@example.com",
      "phone_number": "555-0101"
    },
    "source": {
      "version": 2,
      "connector": "postgresql",
      "name": "postgres-server",
      "ts_ms": 1701234567890,
      "snapshot": "false",
      "db": "testdb",
      "schema": "public",
      "table": "customers",
      "txId": 12345,
      "lsn": 123456789
    },
    "op": "u",
    "ts_ms": 1701234567890,
    "txId": "12345"
  }
}
```

### Operation Types

| Op | Meaning | Before | After |
|---|---------|--------|-------|
| c | Create | null | Data |
| r | Read | null | Data (snapshot) |
| u | Update | Old Data | New Data |
| d | Delete | Old Data | null |

## Extending the Consumer

### Adding Custom Business Logic

1. Modify `RabbitMqConsumer.cs`:

```csharp
private void ProcessCdcEvent(CdcMessage cdcMessage)
{
    var payload = cdcMessage.Payload;
    
    switch (payload.Op)
    {
        case "c":
            HandleCreate(payload);
            break;
        case "u":
            HandleUpdate(payload);
            break;
        case "d":
            HandleDelete(payload);
            break;
        default:
            HandleUnknown(payload);
            break;
    }
}

private void HandleCreate(Payload payload)
{
    // Your insert logic here
    _logger.LogInformation("New customer created: {@Customer}", payload.After);
}

private void HandleUpdate(Payload payload)
{
    // Your update logic here
    _logger.LogInformation(
        "Customer updated from {@Before} to {@After}", 
        payload.Before, 
        payload.After
    );
}

private void HandleDelete(Payload payload)
{
    // Your delete logic here
    _logger.LogInformation("Customer deleted: {@Customer}", payload.Before);
}
```

### Adding Database Storage

```bash
# Add Entity Framework
dotnet add package Microsoft.EntityFrameworkCore.Npgsql
```

```csharp
// Add DbContext service
services.AddDbContext<CustomerDbContext>(options =>
    options.UseNpgsql(configuration.GetConnectionString("DefaultConnection"))
);

// Use in consumer
private async Task SaveCustomerAsync(After customer)
{
    using (var dbContext = serviceProvider.GetRequiredService<CustomerDbContext>())
    {
        var entity = new Customer
        {
            CustomerId = customer.CustomerId.Value,
            FirstName = customer.FirstName,
            LastName = customer.LastName,
            Email = customer.Email,
            PhoneNumber = customer.PhoneNumber
        };
        
        dbContext.Customers.Add(entity);
        await dbContext.SaveChangesAsync();
    }
}
```

### Adding Metrics/Monitoring

```bash
# Add Prometheus metrics
dotnet add package prometheus-net
```

```csharp
// Track events by type
var createCounter = Metrics.CreateCounter("cdc_events_created_total", "Total CREATE events");
var updateCounter = Metrics.CreateCounter("cdc_events_updated_total", "Total UPDATE events");
var deleteCounter = Metrics.CreateCounter("cdc_events_deleted_total", "Total DELETE events");

private void ProcessCdcEvent(Payload payload)
{
    switch (payload.Op)
    {
        case "c":
            createCounter.Inc();
            break;
        case "u":
            updateCounter.Inc();
            break;
        case "d":
            deleteCounter.Inc();
            break;
    }
}
```

## Debugging

### Enable Debug Logging

Update `appsettings.json`:

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Debug",
      "Microsoft": "Information"
    }
  }
}
```

### Inspect Messages

Add logging in message handler:

```csharp
_logger.LogDebug("Raw message: {Message}", message);
var cdcMessage = JsonConvert.DeserializeObject<CdcMessage>(
    message, 
    new JsonSerializerSettings { NullValueHandling = NullValueHandling.Include }
);
_logger.LogDebug("Parsed: {@CdcMessage}", cdcMessage);
```

## Deployment

### Docker Compose

```bash
cd consumer
docker build -t cdc-consumer:latest .
docker-compose -f ../docker/docker-compose.yaml up consumer
```

### Kubernetes

```bash
# Build image
docker build -t your-registry/cdc-consumer:latest .
docker push your-registry/cdc-consumer:latest

# Deploy
kubectl apply -f k8s/cdc-consumer.yaml

# Monitor
kubectl logs -f deployment/cdc-consumer -n cdc-system
```

## Health Checks

Add a health check endpoint:

```csharp
services.AddHealthChecks()
    .AddRabbitMQ(new Uri($"amqp://{hostName}"));

app.MapHealthChecks("/health");
```

## Performance Optimization

### Batch Processing

Process multiple messages before acknowledging:

```csharp
private const int BatchSize = 100;
private List<BasicDeliverEventArgs> _batch = new();

consumer.ReceivedAsync += async (model, ea) =>
{
    _batch.Add(ea);
    
    if (_batch.Count >= BatchSize)
    {
        await ProcessBatch();
    }
};

private async Task ProcessBatch()
{
    foreach (var ea in _batch)
    {
        // Process message
        await _channel.BasicAckAsync(ea.DeliveryTag, ...);
    }
    _batch.Clear();
}
```

### Async I/O

```csharp
public async Task ProcessAsync(CdcMessage message)
{
    var tasks = new[]
    {
        SaveToDatabaseAsync(message),
        UpdateCacheAsync(message),
        SendNotificationAsync(message)
    };
    
    await Task.WhenAll(tasks);
}
```

## Related Documentation

- [README.md](./README.md) - Overview
- [ARCHITECTURE.md](./ARCHITECTURE.md) - System design
- [DEBEZIUM_SETUP.md](./DEBEZIUM_SETUP.md) - Debezium configuration
- [TESTING.md](./TESTING.md) - Testing guide
