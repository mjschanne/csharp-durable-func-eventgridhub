param eventHubSku string
param location string
param resourceGroupPrefix string
param storageAccountId string
var eventHubNamespaceName = '${resourceGroupPrefix}-namespace'
var eventHubName = resourceGroupPrefix
var systemTopicName = '${resourceGroupPrefix}-systemtopic'
var systemTopicSubscriptionName = '${resourceGroupPrefix}-systemtopic-sub'

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2021-11-01' = {
  name: eventHubNamespaceName
  location: location
  sku: {
    name: eventHubSku
    tier: eventHubSku
    capacity: 1
  }
  properties: {
    isAutoInflateEnabled: false
    maximumThroughputUnits: 0
  }
}

resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2021-11-01' = {
  parent: eventHubNamespace
  name: eventHubName
  properties: {
    messageRetentionInDays: 7
    partitionCount: 1
  }
}

resource systemTopic 'Microsoft.EventGrid/systemTopics@2023-06-01-preview' = {
  name: systemTopicName
  location: location
  properties: {
    source: storageAccountId
    topicType: 'Microsoft.Storage.StorageAccounts'
  }
}

resource systemTopicSubscription 'Microsoft.EventGrid/eventSubscriptions@2022-06-15' = {
  name: systemTopicSubscriptionName
  scope: systemTopic
  properties: {
    destination: {
      endpointType: 'EventHub'
      properties: {
        resourceId: eventHub.id
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

output eventHubName string = eventHub.name
output systemTopicName string = systemTopic.name
