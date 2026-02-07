using CdcConsumer.Services;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

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

services.AddSingleton<IMessageConsumer, RabbitMqConsumer>();

var serviceProvider = services.BuildServiceProvider();

// Run consumer
using (var cts = new CancellationTokenSource())
{
    Console.CancelKeyPress += (sender, e) =>
    {
        e.Cancel = true;
        cts.Cancel();
    };

    var consumer = serviceProvider.GetRequiredService<IMessageConsumer>();
    await consumer.StartConsumingAsync(cts.Token);
}
