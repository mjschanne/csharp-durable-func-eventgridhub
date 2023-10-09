// todo: extract into submodules: storage + event hub, function app + app insights

@description('Prefix to use for all resources within the resource group.')
param resourceGroupPrefix string = substring('${uniqueString(resourceGroup().id)}', 0, 5)

@description('Location of all resources')
param location string = resourceGroup().location

@description('Storage Account type for storage account receiving files')
@allowed([
  'Premium_LRS'
  'Premium_ZRS'
  'Standard_GRS'
  'Standard_GZRS'
  'Standard_LRS'
  'Standard_RAGRS'
  'Standard_RAGZRS'
  'Standard_ZRS'
])
param storageAccountType string = 'Standard_LRS'

@description('The name of the storage account receiving incoming files.')
param storageAccountName string = '${resourceGroupPrefix}storage'

@description('The name of the container')
param containerName string = 'container${uniqueString(resourceGroup().id)}'

@description('Specifies the messaging tier for Event Hub Namespace.')
@allowed([
  'Basic'
  'Standard'
])
param eventHubSku string = 'Standard'

var eventHubNamespaceName = '${resourceGroupPrefix}-namespace'
var eventHubName = resourceGroupPrefix
var systemTopicName = '${resourceGroupPrefix}-systemtopic'
var systemTopicSubscriptionName = '${resourceGroupPrefix}-systemtopic-sub'

@description('The name of the function app that you wish to create.')
param appName string = '${resourceGroupPrefix}-func'
var funcStorageAccountName = '${appName}storage'
// todo: clean of undesired characters

@description('Storage Account type for the function app')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
])
param funcStorageAccountType string = 'Standard_LRS'

@description('The name of the application insights resource.')
param applicationInsightsName string = '${resourceGroupPrefix}-appinsights'

resource sa 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'StorageV2'
  properties: {}
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2019-06-01' = {
  name: 'default'
  parent: sa
}

resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2019-06-01' = {
  name: containerName
  parent: blobService
  properties: {
    publicAccess: 'None'
    metadata: {}
  }
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

resource systemTopic 'Microsoft.EventGrid/systemTopics@2023-06-01-preview' = {
  name: systemTopicName
  location: location
  properties: {
    source: sa.id
    topicType: 'Microsoft.Storage.StorageAccounts'
  }
}

resource systemTopicSubscription 'Microsoft.EventGrid/eventSubscriptions@2023-06-01-preview' = {
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

resource funcStorageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: funcStorageAccountName
  location: location
  sku: {
    name: funcStorageAccountType
  }
  kind: 'Storage'
  properties: {
    supportsHttpsTrafficOnly: true
    defaultToOAuthAuthentication: true
  }
}

resource hostingPlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: appName
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {}
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
  }
}

resource functionApp 'Microsoft.Web/sites@2021-03-01' = {
  name: appName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${funcStorageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${funcStorageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${funcStorageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${funcStorageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(appName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }
        {
          name: 'EventHubConnStr'
          value: eventHub.listKeys().primaryConnectionString
        }
        {
          name: 'EventHubName'
          value: systemTopicName
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet'
        }
      ]
      ftpsState: 'FtpsOnly'
      minTlsVersion: '1.2'
    }
    httpsOnly: true
  }
}
