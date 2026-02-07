using RabbitMQ.Client;
using RabbitMQ.Client.Events;
using Newtonsoft.Json;
using CdcConsumer.Models;
using Microsoft.Extensions.Logging;

namespace CdcConsumer.Services
{
    public interface IMessageConsumer
    {
        Task StartConsumingAsync(CancellationToken cancellationToken);
    }

    public class RabbitMqConsumer : IMessageConsumer
    {
        private readonly IConfiguration _configuration;
        private readonly ILogger<RabbitMqConsumer> _logger;
        private IConnection? _connection;
        private IChannel? _channel;

        public RabbitMqConsumer(IConfiguration configuration, ILogger<RabbitMqConsumer> logger)
        {
            _configuration = configuration;
            _logger = logger;
        }

        public async Task StartConsumingAsync(CancellationToken cancellationToken)
        {
            try
            {
                var rabbitMqConfig = _configuration.GetSection("RabbitMq");
                var hostName = rabbitMqConfig["HostName"] ?? "localhost";
                var userName = rabbitMqConfig["UserName"] ?? "guest";
                var password = rabbitMqConfig["Password"] ?? "guest";
                var queueName = rabbitMqConfig["QueueName"] ?? "cdc.customers";

                var factory = new ConnectionFactory()
                {
                    HostName = hostName,
                    UserName = userName,
                    Password = password,
                    DispatchConsumersAsync = true
                };

                _logger.LogInformation("Connecting to RabbitMQ at {HostName}...", hostName);
                _connection = await factory.CreateConnectionAsync(cancellationToken);
                _channel = await _connection.CreateChannelAsync(cancellationToken: cancellationToken);

                // Declare queue
                await _channel.QueueDeclareAsync(
                    queue: queueName,
                    durable: true,
                    exclusive: false,
                    autoDelete: false,
                    cancellationToken: cancellationToken
                );

                _logger.LogInformation("Connected to RabbitMQ. Queue: {QueueName}", queueName);

                // Set QoS
                await _channel.BasicQosAsync(prefetchSize: 0, prefetchCount: 1, global: false, cancellationToken);

                // Create consumer
                var consumer = new AsyncEventingBasicConsumer(_channel);

                consumer.ReceivedAsync += async (model, ea) =>
                {
                    try
                    {
                        var body = ea.Body.ToArray();
                        var message = System.Text.Encoding.UTF8.GetString(body);

                        _logger.LogInformation("Received message: {Message}", message);

                        // Parse CDC message
                        var cdcMessage = JsonConvert.DeserializeObject<CdcMessage>(message);

                        if (cdcMessage?.Payload != null)
                        {
                            LogCdcEvent(cdcMessage.Payload);
                        }

                        // Acknowledge message
                        await _channel.BasicAckAsync(deliveryTag: ea.DeliveryTag, multiple: false, cancellationToken: cancellationToken);
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, "Error processing message");
                        // Negative acknowledgment - requeue
                        await _channel.BasicNackAsync(deliveryTag: ea.DeliveryTag, multiple: false, requeue: true, cancellationToken: cancellationToken);
                    }
                };

                await _channel.BasicConsumeAsync(
                    queue: queueName,
                    autoAck: false,
                    consumerTag: "cdc-consumer",
                    noLocal: false,
                    exclusive: false,
                    arguments: null,
                    consumer: consumer,
                    cancellationToken: cancellationToken
                );

                _logger.LogInformation("Consumer started. Waiting for messages...");

                // Keep consumer running
                await Task.Delay(Timeout.Infinite, cancellationToken);
            }
            catch (OperationCanceledException)
            {
                _logger.LogInformation("Consumer cancelled");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in consumer");
                throw;
            }
            finally
            {
                await CloseAsync();
            }
        }

        private void LogCdcEvent(Payload payload)
        {
            var operation = payload.Op switch
            {
                "c" => "CREATE",
                "u" => "UPDATE",
                "d" => "DELETE",
                "r" => "READ",
                _ => "UNKNOWN"
            };

            _logger.LogInformation(
                "CDC Event - Operation: {Operation}, Table: {Table}, Timestamp: {Timestamp}",
                operation,
                payload.Source?.Table,
                DateTimeOffset.FromUnixTimeMilliseconds(payload.TsMs ?? 0).DateTime
            );

            if (payload.After != null)
            {
                _logger.LogInformation(
                    "New Data - CustomerId: {CustomerId}, Name: {Name}, Email: {Email}",
                    payload.After.CustomerId,
                    $"{payload.After.FirstName} {payload.After.LastName}",
                    payload.After.Email
                );
            }

            if (payload.Before != null && operation == "UPDATE")
            {
                _logger.LogInformation(
                    "Old Data - CustomerId: {CustomerId}, Name: {Name}, Email: {Email}",
                    payload.Before.CustomerId,
                    $"{payload.Before.FirstName} {payload.Before.LastName}",
                    payload.Before.Email
                );
            }
        }

        public async Task CloseAsync()
        {
            if (_channel != null)
            {
                await _channel.CloseAsync();
                _channel.Dispose();
            }

            if (_connection != null)
            {
                await _connection.CloseAsync();
                _connection.Dispose();
            }

            _logger.LogInformation("Connection closed");
        }
    }
}
