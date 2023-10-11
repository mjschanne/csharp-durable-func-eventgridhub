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

@description('The name of the initial container')
param container1Name string = 'container1${uniqueString(resourceGroup().id)}'

@description('The name of the second container')
param container2Name string = 'container2${uniqueString(resourceGroup().id)}'

@description('Specifies the messaging tier for Event Hub Namespace.')
@allowed([
  'Basic'
  'Standard'
])
param eventHubSku string = 'Standard'

@description('The name of the function app that you wish to create.')
param appName string = '${resourceGroupPrefix}-func'

@description('Storage Account type for the function app')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
])
param funcStorageAccountType string = 'Standard_LRS'

@description('The name of the application insights resource.')
param applicationInsightsName string = '${resourceGroupPrefix}-appinsights'

module storage 'modules/storage.bicep' = {
  name: '${resourceGroupPrefix}-storage'
  params: {
    container1Name: container1Name
    container2Name: container2Name
    location: location
    storageAccountName: storageAccountName
    storageAccountType: storageAccountType
  }
}

module eventHub 'modules/eventhub.bicep' = {
  name: '${resourceGroupPrefix}-eventhub'
  dependsOn: [storage]
  params:{
    eventHubSku: eventHubSku
    location: location
    resourceGroupPrefix: resourceGroupPrefix
    storageAccountName: storage.outputs.storageAccountName
  }
}

module function 'modules/function.bicep' = {
  name: '${resourceGroupPrefix}-function'
  dependsOn: [eventHub]
  params: {
    applicationInsightsName: applicationInsightsName
    appName: appName
    container1Name: container1Name
    container2Name: container2Name
    eventHubName: eventHub.outputs.eventHubName
    funcStorageAccountType: funcStorageAccountType
    location: location
    storageAccountId: storage.outputs.storageAccountId
    systemTopicName: eventHub.outputs.systemTopicName
  }
}
module subscription 'modules/subscription.bicep' = {
  name: '${resourceGroupPrefix}-subscription'
  dependsOn: [eventHub, function]
  params: {
    functionAppName: function.outputs.functionAppName
    resourceGroupPrefix: resourceGroupPrefix
    storageAccountName: storage.outputs.storageAccountName
  }
}
