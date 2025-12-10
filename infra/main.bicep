targetScope = 'resourceGroup'

param environmentName string
param location string

var resourceToken = uniqueString(subscription().id, resourceGroup().id, environmentName)

resource appService 'Microsoft.Web/sites@2022-03-01' = {
  name: '${resourceToken}-webapp'
  location: location
  tags: {
    azdServiceName: 'ChristmasTreeWebApp'
    SecurityControl: 'Ignore'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${resourceToken}-identity': {}
    }
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      cors: {
        allowedOrigins: ['*']
      }
      appSettings: [
        {
          name: 'TREE_CONTENT_SAFETY_KEY'
          value: 'YOUR_CONTENT_SAFETY_KEY'
        }
        {
          name: 'TREE_CONTENT_SAFETY_ENDPOINT'
          value: 'YOUR_CONTENT_SAFETY_ENDPOINT'
        }
        {
          name: 'TREE_SPEECH_KEY'
          value: 'YOUR_SPEECH_KEY'
        }
        {
          name: 'TREE_REGION'
          value: 'YOUR_REGION'
        }
      ]
    }
  }
}

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

resource keyVault 'Microsoft.KeyVault/vaults@2021-06-01-preview' = {
  name: '${resourceToken}-keyvault'
  location: location
  tags: {
    SecurityControl: 'Ignore'
  }
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    accessPolicies: []
  }
}

resource servicePrincipal 'Microsoft.Web/sites@2021-02-01' = {
  name: 'ChristmasTreeApp'
  location: resourceGroup().location
  properties: {
    clientAffinityEnabled: true
    httpsOnly: true
  }
}

resource appRoles 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'ChristmasTreeAppRoles'
  location: resourceGroup().location
  properties: {
    appRoles: [
      {
        id: guid('WisherRole')
        displayName: 'Wisher'
        description: 'Can create and view wishes'
        value: 'Wisher'
        allowedMemberTypes: ['User']
        isEnabled: true
      }
      {
        id: guid('AdminRole')
        displayName: 'Admin'
        description: 'Can manage all wishes and users'
        value: 'Admin'
        allowedMemberTypes: ['User']
        isEnabled: true
      }
    ]
  }
}

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'ChristmasTreeAppIdentity'
  location: resourceGroup().location
  tags: {
    SecurityControl: 'Ignore'
  }
}

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

output RESOURCE_GROUP_ID string = resourceGroup().id
output clientId string = userAssignedIdentity.properties.clientId
output tenantId string = subscription().tenantId
