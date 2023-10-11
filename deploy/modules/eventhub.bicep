param eventHubSku string
param location string
param resourceGroupPrefix string
param storageAccountName string
var eventHubNamespaceName = '${resourceGroupPrefix}-namespace'
var eventHubName = resourceGroupPrefix
var systemTopicName = '${resourceGroupPrefix}-systemtopic'

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: storageAccountName
}

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

resource eventHubListenSend 'Microsoft.EventHub/namespaces/eventhubs/authorizationRules@2021-01-01-preview' = {
  parent: eventHub
  name: 'ListenSend'
  properties: {
    rights: [
      'Listen'
      'Send'
    ]
  }
}

resource systemTopic 'Microsoft.EventGrid/systemTopics@2023-06-01-preview' = {
  name: systemTopicName
  location: location
  properties: {
    source: storageAccount.id
    topicType: 'Microsoft.Storage.StorageAccounts'
  }
}

output eventHubName string = eventHub.name
output systemTopicName string = systemTopic.name
output listenSendName string = eventHubListenSend.name
