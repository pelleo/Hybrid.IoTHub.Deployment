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

@minLength(3)
@maxLength(63)
@description('Name of file share.  Must be between 3 and 63 characters long.')
param fileShareName string

@allowed([
  'SMB'
  'NFS'
])
@description('Fileshare type.  Must be SMB or NFS.')
param fileShareType string

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

@description('Storage account prefix')
param storageAccountNamePrefix string

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
var storageAccountName = '${storageAccountNamePrefix}${resourceNameSuffix}'
var nfs =  (fileShareType == 'NFS') ? true : false
var domainNameLabel = '${dnsLabelPrefix}-${resourceNameSuffix}'

//var cloudInitStrBase64 = 'I2Nsb3VkLWNvbmZpZyBwYWNrYWdlX3VwZ3JhZGU6IHRydWUgcGFja2FnZXM6IC0gY3VybCBvdXRwdXQ6IHthbGw6ICd8IHRlZSAtYSAvdmFyL2xvZy9jbG91ZC1pbml0LW91dHB1dC5sb2cnfSBydW5jbWQ6IC0gY3VybCBodHRwczovL3JlbGVhc2VzLnJhbmNoZXIuY29tL2luc3RhbGwtZG9ja2VyLzE4LjA5LnNoIHwgc2ggLSB1c2VybW9kIC1hRyBkb2NrZXIgYWRtaW51c2VyIC0gY3VybCAtc2ZMIGh0dHBzOi8vZ2V0Lmszcy5pbyB8IHNoIC1zIC0gc2VydmVyIC0tdGxzLXNhbiBkZW1vLTM3eWppbjQ2b2FmZXkud2VzdGV1cm9wZS5jbG91ZGFwcC5henVyZS5jb20gLSB1ZncgYWxsb3cgNjQ0My90Y3AgLSB1ZncgYWxsb3cgNDQzL3RjcCAtIGNwIC92YXIvbGliL3JhbmNoZXIvazNzL3NlcnZlci9ub2RlLXRva2VuIC9ob21lL2FkbWludXNlci9ub2RlLXRva2VuIC0gY2hvd24gYWRtaW51c2VyOmFkbWludXNlciAvaG9tZS9hZG1pbnVzZXIvbm9kZS10b2tlbiAtIHNlZCAncy8xMjcuMC4wLjEvZGVtby0zN3lqaW40Nm9hZmV5Lndlc3RldXJvcGUuY2xvdWRhcHAuYXp1cmUuY29tL2cnIC9ldGMvcmFuY2hlci9rM3MvazNzLnlhbWwgPiAvaG9tZS9hZG1pbnVzZXIvazNzLWNvbmZpZyAtIGNobW9kIDYwMCAvaG9tZS9hZG1pbnVzZXIvazNzLWNvbmZpZyAtIGNob3duIGFkbWludXNlcjphZG1pbnVzZXIgL2hvbWUvYWRtaW51c2VyL2szcy1jb25maWcgLSB3Z2V0IC1jIGh0dHBzOi8vZ2V0LmhlbG0uc2gvaGVsbS12My43LjEtbGludXgtYW1kNjQudGFyLmd6IC1QIC9ob21lL2FkbWludXNlciAtIHRhciAteHZmIC9ob21lL2FkbWludXNlci9oZWxtLXYzLjcuMS1saW51eC1hbWQ2NC50YXIuZ3ogLS1kaXJlY3RvcnkgL2hvbWUvYWRtaW51c2VyIC0gbXYgL2hvbWUvYWRtaW51c2VyL2xpbnV4LWFtZDY0L2hlbG0gL3Vzci9sb2NhbC9iaW4vaGVsbSAtIGhlbG0gcmVwbyBhZGQgc3RhYmxlIGh0dHBzOi8vY2hhcnRzLmhlbG0uc2gvc3RhYmxlIC0gaGVsbSByZXBvIHVwZGF0ZSAtIGhlbG0gcmVwbyBhZGQgYXJnbyBodHRwczovL2FyZ29wcm9qLmdpdGh1Yi5pby9hcmdvLWhlbG0gLSBta2RpciAtcCAvaG9tZS9hZG1pbnVzZXIvLmt1YmUgLSBjcCAvZXRjL3JhbmNoZXIvazNzL2szcy55YW1sIC9ob21lL2FkbWludXNlci8ua3ViZS9jb25maWcgLSBrdWJlY3RsIGNyZWF0ZSBucyBhcmdvY2QgLSBoZWxtIHVwZ3JhZGUgLS1rdWJlY29uZmlnIC9ldGMvcmFuY2hlci9rM3MvazNzLnlhbWwgLS1pbnN0YWxsIGRlbW8tYXJnby1jZCBhcmdvL2FyZ28tY2QgLS12ZXJzaW9uIDMuMjYuMTIgLW4gYXJnb2NkIC0gcm0gLXJmIC9ob21lL2FkbWludXNlci9saW51eC1hbWQ2NCAtIGNob3duIC1SIGFkbWludXNlcjphZG1pbnVzZXIgL2hvbWUvYWRtaW51c2VyLy5rdWJlIC0gY2hvd24gYWRtaW51c2VyOmFkbWludXNlciAvaG9tZS9hZG1pbnVzZXIvaGVsbS12My43LjEtbGludXgtYW1kNjQudGFyLmd6Cg=='

var cloudInitStrQuotedBase64 = 'I2Nsb3VkLWNvbmZpZwpwYWNrYWdlX3VwZ3JhZGU6IHRydWUKcGFja2FnZXM6CiAgLSBjdXJsCm91dHB1dDoge2FsbDogJ3wgdGVlIC1hIC92YXIvbG9nL2Nsb3VkLWluaXQtb3V0cHV0LmxvZyd9CnJ1bmNtZDoKICAtIGN1cmwgaHR0cHM6Ly9yZWxlYXNlcy5yYW5jaGVyLmNvbS9pbnN0YWxsLWRvY2tlci8xOC4wOS5zaCB8IHNoCiAgLSB1c2VybW9kIC1hRyBkb2NrZXIgYWRtaW51c2VyCiAgLSBjdXJsIC1zZkwgaHR0cHM6Ly9nZXQuazNzLmlvIHwgc2ggLXMgLSBzZXJ2ZXIgLS10bHMtc2FuIGRlbW8tMzd5amluNDZvYWZleS53ZXN0ZXVyb3BlLmNsb3VkYXBwLmF6dXJlLmNvbQogIC0gdWZ3IGFsbG93IDY0NDMvdGNwCiAgLSB1ZncgYWxsb3cgNDQzL3RjcAogIC0gY3AgL3Zhci9saWIvcmFuY2hlci9rM3Mvc2VydmVyL25vZGUtdG9rZW4gL2hvbWUvYWRtaW51c2VyL25vZGUtdG9rZW4KICAtIGNob3duIGFkbWludXNlcjphZG1pbnVzZXIgL2hvbWUvYWRtaW51c2VyL25vZGUtdG9rZW4KICAtIHNlZCAncy8xMjcuMC4wLjEvZGVtby0zN3lqaW40Nm9hZmV5Lndlc3RldXJvcGUuY2xvdWRhcHAuYXp1cmUuY29tL2cnIC9ldGMvcmFuY2hlci9rM3MvazNzLnlhbWwgPiAvaG9tZS9hZG1pbnVzZXIvazNzLWNvbmZpZwogIC0gY2htb2QgNjAwIC9ob21lL2FkbWludXNlci9rM3MtY29uZmlnCiAgLSBjaG93biBhZG1pbnVzZXI6YWRtaW51c2VyIC9ob21lL2FkbWludXNlci9rM3MtY29uZmlnCiAgLSB3Z2V0IC1jIGh0dHBzOi8vZ2V0LmhlbG0uc2gvaGVsbS12My43LjEtbGludXgtYW1kNjQudGFyLmd6IC1QIC9ob21lL2FkbWludXNlcgogIC0gdGFyIC14dmYgL2hvbWUvYWRtaW51c2VyL2hlbG0tdjMuNy4xLWxpbnV4LWFtZDY0LnRhci5neiAtLWRpcmVjdG9yeSAvaG9tZS9hZG1pbnVzZXIKICAtIG12IC9ob21lL2FkbWludXNlci9saW51eC1hbWQ2NC9oZWxtIC91c3IvbG9jYWwvYmluL2hlbG0KICAtIGhlbG0gcmVwbyBhZGQgc3RhYmxlIGh0dHBzOi8vY2hhcnRzLmhlbG0uc2gvc3RhYmxlCiAgLSBoZWxtIHJlcG8gdXBkYXRlCiAgLSBoZWxtIHJlcG8gYWRkIGFyZ28gaHR0cHM6Ly9hcmdvcHJvai5naXRodWIuaW8vYXJnby1oZWxtCiAgLSBta2RpciAtcCAvaG9tZS9hZG1pbnVzZXIvLmt1YmUKICAtIGNwIC9ldGMvcmFuY2hlci9rM3MvazNzLnlhbWwgL2hvbWUvYWRtaW51c2VyLy5rdWJlL2NvbmZpZwogIC0ga3ViZWN0bCBjcmVhdGUgbnMgYXJnb2NkCiAgLSBoZWxtIHVwZ3JhZGUgLS1rdWJlY29uZmlnIC9ldGMvcmFuY2hlci9rM3MvazNzLnlhbWwgLS1pbnN0YWxsIGRlbW8tYXJnby1jZCBhcmdvL2FyZ28tY2QgLS12ZXJzaW9uIDMuMjYuMTIgLW4gYXJnb2NkCiAgLSBybSAtcmYgL2hvbWUvYWRtaW51c2VyL2xpbnV4LWFtZDY0CiAgLSBjaG93biAtUiBhZG1pbnVzZXI6YWRtaW51c2VyIC9ob21lL2FkbWludXNlci8ua3ViZQogIC0gY2hvd24gYWRtaW51c2VyOmFkbWludXNlciAvaG9tZS9hZG1pbnVzZXIvaGVsbS12My43LjEtbGludXgtYW1kNjQudGFyLmd6Cg=='

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

// Allow kube API connections from anywhere
resource k8sRule 'Microsoft.Network/networkSecurityGroups/securityRules@2021-03-01' = {
  name: 'K8S'
  parent: nsg
  properties: {
    protocol:  'Tcp'
    sourcePortRange:  '*'
    destinationPortRange:  '6443'
    sourceAddressPrefix:  '*'
    destinationAddressPrefix:  '*'
    access:  'Allow'
    priority: 130
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
      //customData: loadFileAsBase64('cloud-init-k3s-argocd.txt')
      customData: cloudInitStrQuotedBase64
      //customData: cloudInitStrBase64
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: false
      }
    }
  }
}

// Create storage account
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: storageAccountSkuName
  }
  kind: 'FileStorage'
  properties: {
    accessTier: 'Hot'
    networkAcls: nfs ? {
      defaultAction: 'Deny'
      virtualNetworkRules: [
        {
          action: 'Allow'
          id: subnet.id
        }
      ]
    } : null
    supportsHttpsTrafficOnly: nfs ? false : true
  }
}

// Create file service
resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2021-04-01' = {
  parent: storageAccount
  name: 'default'
}

// Create file share
resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-04-01' = {
  parent: fileService
  name: fileShareName
  properties: {
    accessTier: 'Premium'
    shareQuota: 128
    enabledProtocols: nfs ? 'NFS' : 'SMB'
    rootSquash: nfs ? 'NoRootSquash' : null
  }
}
