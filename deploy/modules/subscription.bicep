param functionAppName string
param resourceGroupPrefix string
param storageAccountName string
var systemTopicSubscriptionName = '${resourceGroupPrefix}-systemtopic-sub'

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: storageAccountName
}

resource functionApp 'Microsoft.Web/sites@2021-03-01' existing = {
  name: functionAppName
}

// todo: is there a better way to handle the endpointUrl?
resource systemTopicSubscription 'Microsoft.EventGrid/eventSubscriptions@2022-06-15' = {
  name: systemTopicSubscriptionName
  scope: storageAccount
  properties: {
    destination: {
      endpointType: 'WebHook'
      properties: {
        endpointUrl: 'https://${functionApp.properties.defaultHostName}/runtime/webhooks/blobs?functionName=Host.Functions.EventTriggerFunc'
        maxEventsPerBatch: 1
        preferredBatchSizeInKilobytes: 64
      }
    }
    filter: {
      enableAdvancedFilteringOnArrays: true
      includedEventTypes: [
        'Microsoft.Storage.BlobCreated'
      ]
    }
    labels: []
    retryPolicy: {
      eventTimeToLiveInMinutes: 30
      maxDeliveryAttempts: 1440
    }
  }
}
