using Microsoft.Azure.Functions.Worker;
using Microsoft.DurableTask;
using Microsoft.Extensions.Logging;

namespace ExampleOrchestration
{
    public static class DurableOrchestration
    {
        [Function(nameof(DurableOrchestration))]
        public static async Task RunOrchestrator([OrchestrationTrigger] TaskOrchestrationContext context)
        {
            ILogger logger = context.CreateReplaySafeLogger(nameof(DurableOrchestration));
            logger.LogInformation("Saying hello.");

            // add activity function to change one column of the csv and save to a new container

            // add activity function change another column of the csv and save to a new container

            var outputs = new List<string>
            {
                // Replace name and input with values relevant for your Durable Functions Activity
                await context.CallActivityAsync<string>(nameof(SayHello), "Tokyo"),
                await context.CallActivityAsync<string>(nameof(SayHello), "Seattle"),
                await context.CallActivityAsync<string>(nameof(SayHello), "London")
            };

            logger.LogInformation(string.Join(Environment.NewLine, outputs));
        }

        [Function(nameof(SayHello))]
        public static string SayHello([ActivityTrigger] string name, FunctionContext executionContext)
        {
            ILogger logger = executionContext.GetLogger("SayHello");
            logger.LogInformation("Saying hello to {name}.", name);
            return $"Hello {name}!";
        }
    }
}
