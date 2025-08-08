// Parameters
@allowed(['dev', 'prod'])
@description('The target envirionment to deploy to.')
param environment string

@description('The name of the application. This will be used to create unique resource names.')
param appName string

// Variables
var location = resourceGroup().location
var workloadProfileTypeName = 'Consumption'

resource monitoringMetricsPublisherRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '3913510d-42f4-4e42-8a64-420c390055eb'
}

resource keyVaultAdministratorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '00482a5a-887f-4fb3-b363-3b7fe8e74483'
}

resource keyVaultSecretsUserRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '4633458b-17de-408a-b874-0445c86b69e6'
}

resource storageBlobDataContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
}

// Resources
resource storageAccount 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  name: 'st${toLower(appName)}${environment}001'
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}

resource storageAccountRBACContainerApp 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, containerApp.id, storageBlobDataContributorRoleDefinition.id)
  scope: storageAccount
  properties: {
    roleDefinitionId: storageBlobDataContributorRoleDefinition.id
    principalType: 'ServicePrincipal'
    principalId: containerApp.identity.principalId
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'log-${appName}-${environment}'
  location: location
  properties: {
    sku: {
      name: 'pergb2018'
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi-${appName}-${environment}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

resource appInsightsRBACContainerApp 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(appInsights.id, containerApp.id, monitoringMetricsPublisherRoleDefinition.id)
  scope: appInsights
  properties: {
    roleDefinitionId: monitoringMetricsPublisherRoleDefinition.id
    principalType: 'ServicePrincipal'
    principalId: containerApp.identity.principalId
  }
}


resource containerAppEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: 'cae-${appName}-${environment}'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
    workloadProfiles: [
      {
        name: workloadProfileTypeName
        workloadProfileType: 'Consumption'
      }
    ]
  }
}

resource containerApp 'Microsoft.App/containerApps@2024-08-02-preview' = {
  name: 'ca-${toLower(appName)}-${environment}'
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    environmentId: containerAppEnv.id
    workloadProfileName: workloadProfileTypeName
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        allowInsecure: false
      }
    }
    template: {
      containers: [
        {
          name: 'azure-function-convert-email-to-pdf'
          image: 'ghcr.io/miberr/azure-function-convert-email-to-pdf:latest'
          command: []
          args: []
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'AzureWebJobsSecretStorageType'
              value: 'keyvault'
            }
            {
              name: 'AzureWebJobsSecretStorageKeyVaultUri'
              value: keyVault.properties.vaultUri
            }
            {
              name: 'AzureWebJobsStorage__accountName'
              value: storageAccount.name
            }
            {
              name: 'APPLICATIONINSIGHTS_AUTHENTICATION_STRING'
              value: 'Authorization=AAD'
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: appInsights.properties.ConnectionString
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
      }
    }
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2024-04-01-preview' = {
  name: 'kv-${appName}-${environment}'
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    tenantId: subscription().tenantId
  }
}

resource keyVaultRBACContainerApp 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, containerApp.id, keyVaultAdministratorRoleDefinition.id)
  scope: keyVault
  properties: {
    roleDefinitionId: keyVaultAdministratorRoleDefinition.id
    principalType: 'ServicePrincipal'
    principalId: containerApp.identity.principalId
  }
}

resource outlookConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: 'con-${appName}-outlook-${environment}'
  location: location
  properties: {
    displayName: 'con-${appName}-outlook-${environment}'
    api: {
      id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${location}/managedApis/office365'
    }
  }
}

resource onedriveConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: 'con-${appName}-onedrive-${environment}'
  location: location
  properties: {
    displayName: 'con-${appName}-onedrive-${environment}'
    api: {
      id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${location}/managedApis/onedriveforbusiness'
    }
  }
}

resource keyVaultConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: 'con-${appName}-keyvault-${environment}'
  location: location
  properties: {
    displayName: 'con-${appName}-keyvault-${environment}'
    api: {
      id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${location}/managedApis/keyvault'
    }
    parameterValueType: 'Alternative'
    alternativeParameterValues: {
      vaultName: keyVault.name
    }
  }
}

resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: 'logic-${appName}-${environment}'
  location: location
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        endpointUrl: {
          defaultValue: 'http://localhost:7071/api/convertEmlToPdf'
          type: 'String'
        }
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
      }
      triggers: {
        'When_a_new_email_arrives_(V3)': {
          splitOn: '@triggerBody()?[\'value\']'
          type: 'ApiConnectionNotification'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'office365\'][\'connectionId\']'
              }
            }
            fetch: {
              pathTemplate: {
                template: '/v3/Mail/OnNewEmail'
              }
              method: 'get'
              queries: {
                importance: 'Any'
                fetchOnlyWithAttachment: false
                includeAttachments: false
                folderPath: 'Inbox'
              }
            }
            subscribe: {
              body: {
                NotificationUrl: '@listCallbackUrl()'
              }
              pathTemplate: {
                template: '/GraphMailSubscriptionPoke/$subscriptions'
              }
              method: 'post'
              queries: {
                importance: 'Any'
                fetchOnlyWithAttachment: false
                folderPath: 'Inbox'
              }
            }
          }
        }
      }
      actions: {
        Get_secret: {
          runAfter: {
            'Export_email_(V2)': [
              'Succeeded'
            ]
          }
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'keyvault\'][\'connectionId\']'
              }
            }
            method: 'get'
            path: '/secrets/@{encodeURIComponent(\'function--convertmsgtopdf--default\')}/value'
          }
          runtimeConfiguration: {
            secureData: {
              properties: [
                'inputs'
                'outputs'
              ]
            }
          }
        }
        HTTP: {
          runAfter: {
            Get_secret: [
              'Succeeded'
            ]
          }
          type: 'Http'
          inputs: {
            uri: '@parameters(\'endpointUrl\')'
            method: 'POST'
            headers: {
              'x-functions-key': '@{body(\'Get_secret\')?[\'value\']}'
            }
            body: {
              file: '@{base64(body(\'Export_email_(V2)\'))}'
            }
          }
          runtimeConfiguration: {
            contentTransfer: {
              transferMode: 'Chunked'
            }
          }
        }
        'Export_email_(V2)': {
          runAfter: {}
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'office365\'][\'connectionId\']'
              }
            }
            method: 'get'
            path: '/codeless/beta/me/messages/@{encodeURIComponent(triggerBody()?[\'id\'])}/$value'
          }
        }
        Create_file: {
          runAfter: {
            HTTP: [
              'Succeeded'
            ]
          }
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'onedriveforbusiness\'][\'connectionId\']'
              }
            }
            method: 'post'
            body: '@body(\'HTTP\')'
            path: '/datasets/default/files'
            queries: {
              folderPath: '/'
              name: 'email@{ticks(utcNow())}.pdf'
            }
          }
          runtimeConfiguration: {
            contentTransfer: {
              transferMode: 'Chunked'
            }
          }
        }
      }
      outputs: {}
    }
    parameters: {
      endpointUrl: {
        value: 'https://${containerApp.properties.configuration.ingress.fqdn}/api/convertEmlToPdf'
      }
      '$connections': {
        type: 'Object'
        value: {
          office365: {
            id: outlookConnection.properties.api.id
            connectionId: outlookConnection.id
            connectionName: outlookConnection.name
          }
          keyvault: {
            id: keyVaultConnection.properties.api.id
            connectionId: keyVaultConnection.id
            connectionName: keyVaultConnection.name
            connectionProperties: {
              authentication: {
                type: 'ManagedServiceIdentity'
              }
            }
          }
           onedriveforbusiness: {
            id: onedriveConnection.properties.api.id
            connectionId: onedriveConnection.id
            connectionName: onedriveConnection.name
          }
        }
      }
    }
  }
  
  identity: {
    type: 'SystemAssigned'
  }
}

resource keyVaultRBACLogicApp 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, logicApp.id, keyVaultSecretsUserRoleDefinition.id)
  scope: keyVault
  properties: {
    roleDefinitionId: keyVaultSecretsUserRoleDefinition.id
    principalType: 'ServicePrincipal'
    principalId: logicApp.identity.principalId
  }
}

resource logicAppDiagnosticLogs 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'logAnalytics'
  scope: logicApp
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: null
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
            days: 0
            enabled: false
        }
      }
    ]
    metrics: [
      {
        timeGrain: null
        enabled: true
        retentionPolicy: {
            days: 0
            enabled: false
        }
        category: 'AllMetrics'
      }
    ]
  }
}

output endpoint string = 'https://${containerApp.properties.configuration.ingress.fqdn}/api/convertEmlToPdf'
