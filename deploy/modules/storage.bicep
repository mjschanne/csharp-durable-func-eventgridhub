param container1Name string
param container2Name string
param location string
param storageAccountName string
param storageAccountType string

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
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
  parent: storageAccount
}

resource container1 'Microsoft.Storage/storageAccounts/blobServices/containers@2019-06-01' = {
  name: container1Name
  parent: blobService
  properties: {
    publicAccess: 'None'
    metadata: {}
  }
}

resource container2 'Microsoft.Storage/storageAccounts/blobServices/containers@2019-06-01' = {
  name: container2Name
  parent: blobService
  properties: {
    publicAccess: 'None'
    metadata: {}
  }
}

output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
