// Private Link Service (PLS) Infrastructure
// This template creates:
// - Log Analytics Workspace
// - Network resources (VNet, Subnets, Load Balancer)
// - Private Link Service with proper IP configuration

param location string = resourceGroup().location
param environment string = 'prod'
param plsName string = 'pls-${environment}'
param logAnalyticsName string = 'la-${environment}'

// Create Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Create VNet for PLS
resource plsVNet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: 'vnet-pls-${environment}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'subnet-pls-frontend'
        properties: {
          addressPrefix: '10.0.1.0/24'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'subnet-pls-backend'
        properties: {
          addressPrefix: '10.0.2.0/24'
        }
      }
    ]
  }
}

// Create Network Security Group for PLS
resource plsNSG 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: 'nsg-pls-${environment}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowAllInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Create Standard Load Balancer for PLS
resource nlbForPLS 'Microsoft.Network/loadBalancers@2021-05-01' = {
  name: 'nlb-pls-${environment}'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'frontend-ip'
        properties: {
          subnet: {
            id: '${plsVNet.id}/subnets/subnet-pls-frontend'
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'backend-pool'
      }
    ]
    loadBalancingRules: [
      {
        name: 'lb-rule-all'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', 'nlb-pls-${environment}', 'frontend-ip')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'nlb-pls-${environment}', 'backend-pool')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', 'nlb-pls-${environment}', 'health-probe')
          }
          protocol: 'All'
          frontendPort: 0
          backendPort: 0
          enableFloatingIP: false
          idleTimeoutInMinutes: 15
          loadDistribution: 'Default'
        }
      }
    ]
    probes: [
      {
        name: 'health-probe'
        properties: {
          protocol: 'Tcp'
          port: 80
          intervalInSeconds: 15
          numberOfProbes: 2
        }
      }
    ]
  }
}

// Create a NIC for backend pool
resource backendNIC 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: 'nic-backend-${environment}'
  location: location
  properties: {
    networkSecurityGroup: {
      id: plsNSG.id
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: '${plsVNet.id}/subnets/subnet-pls-backend'
          }
          privateIPAllocationMethod: 'Dynamic'
          loadBalancerBackendAddressPools: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'nlb-pls-${environment}', 'backend-pool')
            }
          ]
        }
      }
    ]
  }
  dependsOn: [
    nlbForPLS
  ]
}

// Create Private Link Service
resource privateLinkService 'Microsoft.Network/privateLinkServices@2021-05-01' = {
  name: plsName
  location: location
  properties: {
    loadBalancerFrontendIpConfigurations: [
      {
        id: '${nlbForPLS.id}/frontendIPConfigurations/frontend-ip'
      }
    ]
    ipConfigurations: [
      {
        name: 'pls-ipconfig'
        properties: {
          subnet: {
            id: '${plsVNet.id}/subnets/subnet-pls-frontend'
          }
          privateIPAllocationMethod: 'Dynamic'
          primary: true
        }
      }
    ]
    visibility: {
      subscriptions: [
        subscription().subscriptionId
      ]
    }
    autoApproval: {
      subscriptions: [
        subscription().subscriptionId
      ]
    }
  }
}

// Enable diagnostics for NLB
resource nlbDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: nlbForPLS
  name: 'diag-nlb'
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output plsId string = privateLinkService.id
output plsName string = privateLinkService.name
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
output plsVNetId string = plsVNet.id
output nlbId string = nlbForPLS.id
