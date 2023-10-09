using System;
using Azure.Messaging.EventHubs;
using Microsoft.Azure.Functions.Worker;
using Microsoft.DurableTask.Client;
using Microsoft.Extensions.Logging;

namespace ExampleOrchestration
{
    public class EventTriggerFunc
    {
        private readonly ILogger<EventTriggerFunc> _logger;

        public EventTriggerFunc(ILogger<EventTriggerFunc> logger)
        {
            _logger = logger;
        }

        [Function(nameof(EventTriggerFunc))]
        public async Task Run([EventHubTrigger("%EventHubName%", Connection = "EventHubConnStr")] EventData[] events
            [DurableClient] DurableTaskClient client,
            FunctionContext executionContext)
        {
            foreach (EventData @event in events)
            {
                _logger.LogInformation("Event Body: {body}", @event.Body);
                _logger.LogInformation("Event Content-Type: {contentType}", @event.ContentType);
                string instanceId = await client.ScheduleNewOrchestrationInstanceAsync(nameof(DurableOrchestration), @event);
            }
        }
    }
}
