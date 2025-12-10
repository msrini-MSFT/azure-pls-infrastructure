// Private Endpoints and VM Infrastructure
// This template creates:
// - Consumer VNet and Subnets
// - 20 Private Endpoints connected to PLS
// - VM for traffic generation through PEs
// - Network interfaces and monitoring

param location string = resourceGroup().location
param environment string = 'prod'
param plsResourceId string
param logAnalyticsWorkspaceId string
param peCount int = 20
param vmAdminUsername string = 'azureuser'
@secure()
param vmAdminPassword string = newGuid()

// Create Consumer VNet
resource consumerVNet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: 'vnet-consumer-${environment}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.1.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'subnet-vm'
        properties: {
          addressPrefix: '10.1.0.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'subnet-pe'
        properties: {
          addressPrefix: '10.1.1.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

// Create Network Security Group for Consumer VNet
resource consumerNSG 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: 'nsg-consumer-${environment}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowSSH'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowRDP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 101
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowAllOutbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
    ]
  }
}

// Create Network Interface for VM
resource vmNIC 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: 'nic-vm-${environment}'
  location: location
  properties: {
    networkSecurityGroup: {
      id: consumerNSG.id
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: '${consumerVNet.id}/subnets/subnet-vm'
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: vmPublicIP.id
          }
        }
      }
    ]
  }
}

// Create Public IP for VM
resource vmPublicIP 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: 'pip-vm-${environment}'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Create Virtual Machine
resource vm 'Microsoft.Compute/virtualMachines@2021-07-01' = {
  name: 'vm-${environment}'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    osProfile: {
      computerName: 'vm-${environment}'
      adminUsername: vmAdminUsername
      adminPassword: vmAdminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: '18_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vmNIC.id
          properties: {
            primary: true
          }
        }
      ]
    }
  }
}

// Create Private Endpoints (20 total)
resource privateEndpoints 'Microsoft.Network/privateEndpoints@2021-05-01' = [for i in range(0, peCount): {
  name: 'pe-pls-${i + 1}-${environment}'
  location: location
  properties: {
    subnet: {
      id: '${consumerVNet.id}/subnets/subnet-pe'
    }
    privateLinkServiceConnections: [
      {
        name: 'pls-connection-${i + 1}'
        properties: {
          privateLinkServiceId: plsResourceId
          requestMessage: 'Connection from PE ${i + 1}'
          groupIds: []
        }
      }
    ]
  }
}]

// Enable diagnostics for Network Interfaces
resource vmNICDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: vmNIC
  name: 'diag-nic-vm'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// Enable VM Guest diagnostics
resource vmDiagnosticsExtension 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' = {
  parent: vm
  name: 'Microsoft.Azure.Monitor.AzureMonitorLinuxAgent'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorLinuxAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    settings: {}
  }
}

output vmId string = vm.id
output vmNICId string = vmNIC.id
output consumerVNetId string = consumerVNet.id
output vmPublicIPAddress string = vmPublicIP.properties.ipAddress
output privateEndpointCount int = peCount
