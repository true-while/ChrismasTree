targetScope = 'resourceGroup'

param environmentName string
param location string

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
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${resourceToken}-identity': {}
    }
  }
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
          value: 'your-key-here'
        }
        {
          name: 'TREE_SPEECH_KEY'
          value: 'your-key-here'
        }
        {name:'TREE_REGION'
      value: 'your-region-here'} 

        {
          name: 'TREE_CONTENT_SAFETY_ENDPOINT'
          value: 'your-key-here'
        }

        {
          name: 'TREE_CLIENT_ID'
          value: ''
        }
        {
          name: 'TREE_TENANT_ID'
          value: ''
        }
        {
          name: 'TREE_CLIENT_SECRET'
          value: ''
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

resource webApp 'Microsoft.Web/sites@2024-04-01' = {
  name: 'myWebApp'
  location: resourceGroup().location
  kind: 'app'
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      appSettings: [
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '14.17.0'
        }
      ]
    }
  }
  tags: {
    environment: 'production'
  }
}

output RESOURCE_GROUP_ID string = resourceGroup().id
output clientId string = userAssignedIdentity.properties.clientId
output tenantId string = subscription().tenantId
