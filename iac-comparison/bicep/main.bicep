targetScope = 'subscription'

// ---------- Parameters ----------
param location string = 'westeurope'
param resourceGroupName string = 'rg-iac-bicep-demo'
param appServicePlanName string = 'asp-bicep-demo'
param webAppName string = 'app-bicep-demo'
param storageAccountName string = 'stbicepdemo'
param skuName string = 'B1'

// ---------- Resource Group ----------
resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceGroupName
  location: location
}

// ---------- Module: resources inside the resource group ----------
module resources 'resources.bicep' = {
  name: 'resourcesDeployment'
  scope: rg
  params: {
    location: location
    appServicePlanName: appServicePlanName
    webAppName: webAppName
    storageAccountName: storageAccountName
    skuName: skuName
  }
}

// ---------- Outputs ----------
output webAppUrl string = resources.outputs.webAppUrl
