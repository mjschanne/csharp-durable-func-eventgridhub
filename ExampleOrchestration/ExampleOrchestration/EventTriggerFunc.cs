using System;
using System.Reactive.Linq;
using System.Text;
using Azure.Messaging.EventHubs;
using Microsoft.Azure.Functions.Worker;
using Microsoft.DurableTask.Client;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;

namespace ExampleOrchestration;

public class EventTriggerFunc
{
    private readonly ILogger<EventTriggerFunc> _logger;

    public EventTriggerFunc(ILogger<EventTriggerFunc> logger)
    {
        _logger = logger;
    }

    [Function(nameof(EventTriggerFunc))]
    public async Task Run([EventHubTrigger("%EventHubName%", Connection = "EventHubConnStr")] EventData[] events,
        [DurableClient] DurableTaskClient client,
        FunctionContext executionContext)
    {
        foreach (EventData @event in events)
        {
            _logger.LogInformation("Event Body: {body}", @event.Body);
            _logger.LogInformation("Event Content-Type: {contentType}", @event.ContentType);

            try
            {
                var dataArray = JsonConvert.DeserializeObject<List<BlobEvent>>(@event.EventBody.ToString());

                var blobName = dataArray.FirstOrDefault()?.Data?.Url?.Split('/')?.LastOrDefault();

                var orchestrationInput = new OrchestrationInput
                {
                    BlobName = blobName ?? string.Empty
                };

                var instanceId = await client.ScheduleNewOrchestrationInstanceAsync(nameof(DurableOrchestration), orchestrationInput);

                _logger.LogInformation($"Initialized orchestration with ID = '{instanceId}' for blob = '{blobName}'.");
            }
            catch (Exception exception)
            {
                _logger.LogError(exception, exception.Message);
            }
        }
    }
}

public class OrchestrationInput
{
    public string BlobName { get; set; } = "";
}

public class BlobEvent
{
    public string Topic { get; set; } = "";
    public string Subject { get; set; } = "";
    public string EventType { get; set; } = "";
    public string Id { get; set; } = "";
    public string DataVersion { get; set; } = "";
    public string MetadataVersion { get; set; } = "";
    public string EventTime { get; set; } = "";
    public BlobEventData? Data { get; set; }
}

public class BlobEventData
{
    public string Api { get; set; } = "";
    public string BlobType { get; set; } = "";
    public string ClientRequestId { get; set; } = "";
    public int ContentLength { get; set; } = 0;
    public string eTag { get; set; } = "";
    public string RequestId { get; set; } = "";
    public string Sequencer { get; set; } = "";
    public string Url { get; set; } = "";
}

public class StorageDiagnostics
{
    public string BatchId { get; set; } = "";
}
