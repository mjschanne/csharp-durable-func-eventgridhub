using Azure.Storage.Blobs;
using Microsoft.Azure.Functions.Worker;
using Microsoft.DurableTask;
using Microsoft.Extensions.Logging;

namespace ExampleOrchestration;

public class DurableOrchestration
{
    private readonly BlobContainerClient _container1Client;
    private readonly BlobContainerClient _container2Client;

    public DurableOrchestration(BlobServiceClient blobServiceClient)
    {
        var container1Name = Environment.GetEnvironmentVariable("Container1Name");
        var container2Name = Environment.GetEnvironmentVariable("Container2Name");

        _container1Client = blobServiceClient.GetBlobContainerClient(container1Name);
        _container2Client = blobServiceClient.GetBlobContainerClient(container2Name);
    }

    [Function(nameof(DurableOrchestration))]
    public static async Task RunOrchestrator([OrchestrationTrigger] TaskOrchestrationContext context)
    {
        ILogger logger = context.CreateReplaySafeLogger(nameof(DurableOrchestration));

        var orchestrationInput = context.GetInput<OrchestrationInput>();

        if (orchestrationInput == null)
        {
            logger.LogInformation($"No orchestration input found.");

            return;
        }

        logger.LogInformation($"Initiating transfomration workflow for blobName = '{orchestrationInput.BlobName}'");

        try
        {
            var stage1Status = await context.CallActivityAsync<TransformationStatus>(nameof(TransformFileAsync), orchestrationInput);
            var stage2Status = await context.CallActivityAsync<TransformationStatus>("TransformFile2Async", orchestrationInput);
        }
        catch (Exception exception)
        {
            LogErrorRecursive(logger, exception);

            // Error handling or compensation goes here, include retry/circuit breaker logic for transient issues
        }
    }

    public class TransformFileInput
    {
        public string BlobName { get; set; } = "";
    }

    private static void LogErrorRecursive(ILogger logger, Exception exception)
    {
        if (!string.IsNullOrWhiteSpace(exception?.Message))
            logger.LogError(exception, exception?.Message);

        if (exception?.InnerException != null)
            LogErrorRecursive(logger, exception.InnerException);
    }

    [Function(nameof(TransformFileAsync))]
    public async Task<TransformationStatus> TransformFileAsync([ActivityTrigger] OrchestrationInput orchestrationInput, FunctionContext executionContext)
    {
        ILogger logger = executionContext.GetLogger(nameof(TransformFileAsync));

        try
        {
            var blobClient = _container1Client.GetBlobClient(orchestrationInput.BlobName);

            using var stream = await blobClient.OpenReadAsync();

            // transform the stream in some way

            // send change to next destination
            await _container2Client.UploadBlobAsync(orchestrationInput.BlobName, stream);
        }
        catch (Exception exception)
        {
            logger.LogError(exception, exception.Message);

            return TransformationStatus.Failed;
        }

        return TransformationStatus.Completed;
    }

    // change a different column of the csv, save to final container location
    [Function(nameof(TransformFile2Async))]
    public async Task<TransformationStatus> TransformFile2Async([ActivityTrigger] OrchestrationInput orchestrationInput, FunctionContext executionContext)
    {
        ILogger logger = executionContext.GetLogger("TransformFileAsync");

        try
        {
            var blobClient = _container2Client.GetBlobClient(orchestrationInput.BlobName);

            using var stream = await blobClient.OpenReadAsync();

            // transform the stream in some way

            // send it to next destination

            // clean blob from prior location now that this step is complete
            await _container1Client.DeleteBlobAsync(orchestrationInput.BlobName);
        }
        catch (Exception exception)
        {
            logger.LogError(exception, exception.Message);

            return TransformationStatus.Failed;
        }

        return TransformationStatus.Completed;
    }

    public enum TransformationStatus
    {
        Completed,
        Failed
    }
}
