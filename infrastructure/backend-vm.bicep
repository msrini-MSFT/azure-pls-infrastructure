param location string = resourceGroup().location
param environment string = 'prod'
param backendVmName string = 'backend-vm-1'
param vmAdminUsername string = 'azureuser'
@secure()
param vmAdminPassword string
param loadBalancerName string = 'nlb-pls-${environment}'
param vnetName string = 'vnet-pls-${environment}'
param subnetName string = 'subnet-pls-backend'

var nicName = 'nic-backend-vm1'

resource lb 'Microsoft.Network/loadBalancers@2021-05-01' existing = {
  name: loadBalancerName
}

resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: vnetName
}

resource backendPool 'Microsoft.Network/loadBalancers/backendAddressPools@2021-05-01' existing = {
  parent: lb
  name: 'backend-pool'
}

// Create NIC in backend subnet and attach backend pool
resource nic 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: '${vnet.id}/subnets/${subnetName}'
          }
          privateIPAllocationMethod: 'Dynamic'
          loadBalancerBackendAddressPools: [
            {
              id: backendPool.id
            }
          ]
        }
      }
    ]
  }
  dependsOn: [lb]
}

// Create VM attached to the NIC
resource vm 'Microsoft.Compute/virtualMachines@2021-07-01' = {
  name: backendVmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B1ms'
    }
    osProfile: {
      computerName: backendVmName
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
        sku: '18.04-LTS'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            primary: true
          }
        }
      ]
    }
  }
  dependsOn: [nic]
}

output backendNicId string = nic.id
output backendVmId string = vm.id
