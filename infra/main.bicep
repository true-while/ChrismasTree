targetScope = 'resourceGroup'

param environmentName string
param location string = 'canadaeast'

var resourceToken = uniqueString(subscription().id, resourceGroup().id, environmentName)

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: '${resourceToken}-plan'
  location: location
  tags: {
    SecurityControl: 'Ignore'
  }
  sku: {
    name: 'F1'
    capacity: 1
  }
}

resource appService 'Microsoft.Web/sites@2022-03-01' = {
  name: '${resourceToken}-webapp'
  location: location
  tags: {
    azdServiceName: 'ChristmasTreeWebApp'
    SecurityControl: 'Ignore'
  }
  kind: 'app'
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      cors: {
        allowedOrigins: ['*']
      }
      appSettings: [
        {
          name: 'TREE_CONTENT_SAFETY_KEY'
          value: '' // To be set by post-deployment script
        }
        {
          name: 'TREE_REGION'
          value: location
        }
        {
          name: 'TREE_CONTENT_SAFETY_ENDPOINT'
          value: '' // To be set by post-deployment script
        }
        {
          name: 'TREE_CLIENT_ID'
          value: '' // To be set by post-deployment script
        }
        {
          name: 'TREE_TENANT_ID'
          value: '' // To be set by post-deployment script
        }
        {
          name: 'TREE_CLIENT_SECRET'
          value: '' // To be set by post-deployment script
        }
      ]
    }
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${resourceToken}-appinsights'
  location: location
  tags: {
    SecurityControl: 'Ignore'
  }
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: '${resourceToken}-loganalytics'
  location: location
  tags: {
    SecurityControl: 'Ignore'
  }
  properties: {}
}

// Add post-deployment PowerShell script to handle App Registration and update Web App settings.

resource wisherRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(resourceGroup().id, 'WisherRole')
  properties: {
    roleName: 'Wisher'
    description: 'Can create and view wishes'
    type: 'CustomRole'
    permissions: [
      {
        actions: ['Microsoft.Web/sites/*/read', 'Microsoft.Web/sites/*/write']
        notActions: []
      }
    ]
    assignableScopes: [resourceGroup().id]
  }
}

resource adminRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(resourceGroup().id, 'AdminRole')
  properties: {
    roleName: 'Admin'
    description: 'Can manage all wishes and users'
    type: 'CustomRole'
    permissions: [
      {
        actions: ['Microsoft.Web/sites/*']
        notActions: []
      }
    ]
    assignableScopes: [resourceGroup().id]
  }
}

resource contentSafetyService 'Microsoft.CognitiveServices/accounts@2022-03-01' = {
  name: '${resourceToken}-contentsafety'
  location: location
  kind: 'ContentSafety'
  sku: {
    name: 'S0'
  }
  properties: {
    disableLocalAuth: false
  }
}

output RESOURCE_GROUP_ID string = resourceGroup().id
