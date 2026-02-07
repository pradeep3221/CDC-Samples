using System;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Confluent.Kafka;
using RabbitMQ.Client;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace KafkaRabbitMqBridge
{
    class Program
    {
        static async Task Main(string[] args)
        {
            // Build configuration
            var configuration = new ConfigurationBuilder()
                .SetBasePath(Directory.GetCurrentDirectory())
                .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
                .AddEnvironmentVariables()
                .Build();

            // Build DI container
            var services = new ServiceCollection();

            services.AddSingleton(configuration);
            services.AddLogging(builder =>
            {
                builder.AddConsole();
                builder.AddConfiguration(configuration.GetSection("Logging"));
            });

            var serviceProvider = services.BuildServiceProvider();
            var logger = serviceProvider.GetRequiredService<ILogger<Program>>();

            try
            {
                var kafkaConfig = configuration.GetSection("Kafka");
                var rabbitMqConfig = configuration.GetSection("RabbitMq");

                var bootstrapServers = kafkaConfig["BootstrapServers"] ?? "localhost:9092";
                var topicPattern = kafkaConfig["TopicPattern"] ?? "sqlserver.*";
                var consumerGroup = kafkaConfig["ConsumerGroup"] ?? "kafka-rabbitmq-bridge";

                var rabbitMqHost = rabbitMqConfig["HostName"] ?? "localhost";
                var rabbitMqUser = rabbitMqConfig["UserName"] ?? "guest";
                var rabbitMqPassword = rabbitMqConfig["Password"] ?? "guest";

                logger.LogInformation("Starting Kafka-RabbitMQ Bridge");
                logger.LogInformation("Kafka Bootstrap Servers: {BootstrapServers}", bootstrapServers);
                logger.LogInformation("Kafka Topic Pattern: {TopicPattern}", topicPattern);
                logger.LogInformation("RabbitMQ Host: {RabbitMqHost}", rabbitMqHost);

                using (var cts = new CancellationTokenSource())
                {
                    Console.CancelKeyPress += (sender, e) =>
                    {
                        e.Cancel = true;
                        cts.Cancel();
                    };

                    await RunBridgeAsync(bootstrapServers, topicPattern, consumerGroup, rabbitMqHost, rabbitMqUser, rabbitMqPassword, logger, cts.Token);
                }
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Fatal error in bridge");
                Environment.Exit(1);
            }
        }

        static async Task RunBridgeAsync(string bootstrapServers, string topicPattern, string consumerGroup,
            string rabbitMqHost, string rabbitMqUser, string rabbitMqPassword,
            ILogger<Program> logger, CancellationToken cancellationToken)
        {
            // Create Kafka consumer
            var consumerConfig = new ConsumerConfig
            {
                BootstrapServers = bootstrapServers,
                GroupId = consumerGroup,
                AutoOffsetReset = AutoOffsetReset.Earliest,
                EnableAutoCommit = true
            };

            // Create RabbitMQ connection
            var factory = new ConnectionFactory()
            {
                HostName = rabbitMqHost,
                UserName = rabbitMqUser,
                Password = rabbitMqPassword,
                DispatchConsumersAsync = true
            };

            using (var consumer = new ConsumerBuilder<string, string>(consumerConfig)
                .Build())
            using (var connection = await factory.CreateConnectionAsync(cancellationToken))
            using (var channel = await connection.CreateChannelAsync(cancellationToken: cancellationToken))
            {
                try
                {
                    // Subscribe to topics matching pattern
                    consumer.Subscribe(topicPattern);
                    logger.LogInformation("Subscribed to topic pattern: {TopicPattern}", topicPattern);

                    while (!cancellationToken.IsCancellationRequested)
                    {
                        try
                        {
                            var consumeResult = consumer.Consume(1000);

                            if (consumeResult != null)
                            {
                                logger.LogInformation("Received message from topic: {Topic}, Partition: {Partition}, Offset: {Offset}",
                                    consumeResult.Topic, consumeResult.Partition, consumeResult.Offset);

                                // Convert topic name to queue name (e.g., sqlserver.dbo.Customers -> cdc.customers)
                                var queueName = $"cdc.{consumeResult.Topic.Split('.').Last().ToLower()}";

                                // Declare queue in RabbitMQ
                                await channel.QueueDeclareAsync(
                                    queue: queueName,
                                    durable: true,
                                    exclusive: false,
                                    autoDelete: false,
                                    cancellationToken: cancellationToken
                                );

                                // Publish to RabbitMQ
                                var properties = new BasicProperties()
                                {
                                    Persistent = true,
                                    Headers = new Dictionary<string, object?>
                                    {
                                        { "kafka-topic", consumeResult.Topic },
                                        { "kafka-partition", consumeResult.Partition.Value },
                                        { "kafka-offset", consumeResult.Offset.Value }
                                    }
                                };

                                var body = Encoding.UTF8.GetBytes(consumeResult.Value);

                                await channel.BasicPublishAsync(
                                    exchange: "",
                                    routingKey: queueName,
                                    mandatory: false,
                                    basicProperties: properties,
                                    body: body,
                                    cancellationToken: cancellationToken
                                );

                                logger.LogInformation("Published message to RabbitMQ queue: {QueueName}", queueName);
                            }
                        }
                        catch (ConsumeException ex)
                        {
                            logger.LogError(ex, "Error consuming message from Kafka");
                        }
                        catch (Exception ex)
                        {
                            logger.LogError(ex, "Error processing message");
                        }
                    }
                }
                finally
                {
                    consumer.Unsubscribe();
                    consumer.Close();
                }
            }
        }
    }
}
