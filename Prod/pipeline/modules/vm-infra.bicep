param environmentType string
param linuxAdminUsername string
//@secure()
param sshRSAPublicKey string
param dnsLabelPrefix string
param location string

@description('The name of the Virtual Machine.')
param vmName string 

@description('Size of virtual machine.')
param vmSize string

@description('Name of network security group')
var nsgName = 'onprem-nsg'

@description('Name of virtual network')
param vnetName string = 'onprem-vnet'

@description('Name of subnet')
var subnetName = 'onprem-snet'

@description('List of service endpoints to be enabled on subnet' )
param serviceEndpoints array = [
  {
    service: 'Microsoft.Storage'
  }
]

param tags object

@description('Address space of virtual network')
param vnetAddressPrefix string = '10.1.0.0/16'

@description('Address space of subnet prefix')
param subnetAddressPrefix string = '10.1.0.0/24'

@description('Name of public IP resource')
var publicIPAddressName = '${vmName}-public-ip'

@description('Name of virtual NIC')
var networkInterfaceName = '${vmName}-nic'
var subnetRef = '${vnet.id}/subnets/${subnetName}'
var osDiskType = 'Standard_LRS'

@description('Disable password login and configure SSH')
var linuxConfiguration = {
  disablePasswordAuthentication: true
  ssh: {
    publicKeys: [
      {
        path: '/home/${linuxAdminUsername}/.ssh/authorized_keys'
        keyData: sshRSAPublicKey
      }
    ]
  }
}

var storageAccountSkuName = (environmentType == 'prod') ? 'Premium_ZRS' : 'Premium_LRS'
var resourceNameSuffix  = uniqueString(resourceGroup().id)
var domainNameLabel = '${dnsLabelPrefix}-${resourceNameSuffix}'

// Create virtual network
resource vnet 'Microsoft.Network/virtualNetworks@2021-03-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
  }
}

// Create subnet
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2021-03-01' =  {
  parent: vnet
  name: subnetName
  properties: {
    addressPrefix: subnetAddressPrefix
    serviceEndpoints: serviceEndpoints
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

// Create empty network security group
resource nsg 'Microsoft.Network/networkSecurityGroups@2021-03-01' = {
  name: nsgName
  location: location
  tags: tags
}

// Allow SSH connections from anywhere
resource sshRule 'Microsoft.Network/networkSecurityGroups/securityRules@2021-03-01' = {
  name: 'SSH'
  parent: nsg
  properties : {
    protocol: 'Tcp' 
    sourcePortRange:  '*'
    destinationPortRange:  '22'
    sourceAddressPrefix:  '*'
    destinationAddressPrefix: '*'
    access:  'Allow'
    priority: 100
    direction: 'Inbound'
    sourcePortRanges: []
    destinationPortRanges: []
    sourceAddressPrefixes: []
    destinationAddressPrefixes: []
  }
}

// Allow HTTP connections from anywhere
resource httpRule 'Microsoft.Network/networkSecurityGroups/securityRules@2021-03-01' = {
  name: 'HTTP'
  parent: nsg
  properties: {
    protocol:  'Tcp'
    sourcePortRange:  '*'
    destinationPortRange:  '80'
    sourceAddressPrefix:  '*'
    destinationAddressPrefix:  '*'
    access:  'Allow'
    priority: 110
    direction:  'Inbound'
    sourcePortRanges: []
    destinationPortRanges: []
    sourceAddressPrefixes: []
    destinationAddressPrefixes: []
  }
}

// Allow HTTPS connections from anywhere
resource httpsRule 'Microsoft.Network/networkSecurityGroups/securityRules@2021-03-01' = {
  name: 'HTTPS'
  parent: nsg
  properties: {
    protocol:  'Tcp'
    sourcePortRange:  '*'
    destinationPortRange:  '443'
    sourceAddressPrefix:  '*'
    destinationAddressPrefix:  '*'
    access:  'Allow'
    priority: 120
    direction:  'Inbound'
    sourcePortRanges: []
    destinationPortRanges: []
    sourceAddressPrefixes: []
    destinationAddressPrefixes: []
  }
}

// Create Public IP
resource publicIP 'Microsoft.Network/publicIPAddresses@2021-03-01' = {
  name: publicIPAddressName
  location: location
  tags: tags
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: domainNameLabel
    }
    idleTimeoutInMinutes: 4
  }
  sku: {
    name: 'Basic'
  }
}

// Create virtual network interface card
resource nic 'Microsoft.Network/networkInterfaces@2021-03-01' = {
  name: networkInterfaceName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetRef
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIP.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

// Create virtual machine
resource vm 'Microsoft.Compute/virtualMachines@2021-03-01' = {
  name: vmName
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
      }
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: '18.04-LTS'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    osProfile: {
      computerName: vmName
      adminUsername: linuxAdminUsername
      //adminPassword: adminPasswordOrKey
      linuxConfiguration: linuxConfiguration
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: false
      }
    }
  }
}
