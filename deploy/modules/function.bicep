param applicationInsightsName string
param appName string
param container1Name string
param container2Name string
param listenSendName string
param funcStorageAccountType string
param location string
param storageAccountName string
param systemTopicName string
var cleanAppName = replace(appName, '-', '')
var funcStorageAccountName = '${cleanAppName}storage'

resource eventHubListenSend 'Microsoft.EventHub/namespaces/eventhubs/authorizationRules@2021-01-01-preview' existing = {
  name: listenSendName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: storageAccountName
}

resource funcStorageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
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

var funcStorageAccountKey = funcStorageAccount.listKeys().keys[0].value
var endpointSuffix = environment().suffixes.storage
var storageAccountKey = storageAccount.listKeys().keys[0].value

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
          value: 'DefaultEndpointsProtocol=https;AccountName=${funcStorageAccountName};EndpointSuffix=${endpointSuffix};AccountKey=${funcStorageAccountKey}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${funcStorageAccountName};EndpointSuffix=${endpointSuffix};AccountKey=${funcStorageAccountKey}'
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
          value: eventHubListenSend.listKeys().primaryConnectionString
        }
        {
          name: 'EventHubName'
          value: systemTopicName
        }
        {
          name: 'BlobStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccountKey};EndpointSuffix=${endpointSuffix}'
        } 
        {
          name: 'Container1Name'
          value: container1Name
        }
        {
          name: 'Container2Name'
          value: container2Name
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

output functionAppName string = functionApp.name
