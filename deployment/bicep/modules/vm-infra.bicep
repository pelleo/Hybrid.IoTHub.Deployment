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

@description('Name of managed identity used when creating cloud-init.yaml dynmically')
var identityName = 'boot'
var customRoleName = 'deployment-script-minimum-privilege-for-deployment-principal'

//var cloudInitStrQuotedBase64 = 'I2Nsb3VkLWNvbmZpZwpwYWNrYWdlX3VwZ3JhZGU6IHRydWUKcGFja2FnZXM6CiAgLSBjdXJsCm91dHB1dDoge2FsbDogJ3wgdGVlIC1hIC92YXIvbG9nL2Nsb3VkLWluaXQtb3V0cHV0LmxvZyd9CnJ1bmNtZDoKICAtIGN1cmwgaHR0cHM6Ly9yZWxlYXNlcy5yYW5jaGVyLmNvbS9pbnN0YWxsLWRvY2tlci8xOC4wOS5zaCB8IHNoCiAgLSB1c2VybW9kIC1hRyBkb2NrZXIgYWRtaW51c2VyCiAgLSBjdXJsIC1zZkwgaHR0cHM6Ly9nZXQuazNzLmlvIHwgc2ggLXMgLSBzZXJ2ZXIgLS10bHMtc2FuIGRlbW8tMzd5amluNDZvYWZleS53ZXN0ZXVyb3BlLmNsb3VkYXBwLmF6dXJlLmNvbQogIC0gdWZ3IGFsbG93IDY0NDMvdGNwCiAgLSB1ZncgYWxsb3cgNDQzL3RjcAogIC0gY3AgL3Zhci9saWIvcmFuY2hlci9rM3Mvc2VydmVyL25vZGUtdG9rZW4gL2hvbWUvYWRtaW51c2VyL25vZGUtdG9rZW4KICAtIGNob3duIGFkbWludXNlcjphZG1pbnVzZXIgL2hvbWUvYWRtaW51c2VyL25vZGUtdG9rZW4KICAtIHNlZCAncy8xMjcuMC4wLjEvZGVtby0zN3lqaW40Nm9hZmV5Lndlc3RldXJvcGUuY2xvdWRhcHAuYXp1cmUuY29tL2cnIC9ldGMvcmFuY2hlci9rM3MvazNzLnlhbWwgPiAvaG9tZS9hZG1pbnVzZXIvazNzLWNvbmZpZwogIC0gY2htb2QgNjAwIC9ob21lL2FkbWludXNlci9rM3MtY29uZmlnCiAgLSBjaG93biBhZG1pbnVzZXI6YWRtaW51c2VyIC9ob21lL2FkbWludXNlci9rM3MtY29uZmlnCiAgLSB3Z2V0IC1jIGh0dHBzOi8vZ2V0LmhlbG0uc2gvaGVsbS12My43LjEtbGludXgtYW1kNjQudGFyLmd6IC1QIC9ob21lL2FkbWludXNlcgogIC0gdGFyIC14dmYgL2hvbWUvYWRtaW51c2VyL2hlbG0tdjMuNy4xLWxpbnV4LWFtZDY0LnRhci5neiAtLWRpcmVjdG9yeSAvaG9tZS9hZG1pbnVzZXIKICAtIG12IC9ob21lL2FkbWludXNlci9saW51eC1hbWQ2NC9oZWxtIC91c3IvbG9jYWwvYmluL2hlbG0KICAtIGhlbG0gcmVwbyBhZGQgc3RhYmxlIGh0dHBzOi8vY2hhcnRzLmhlbG0uc2gvc3RhYmxlCiAgLSBoZWxtIHJlcG8gdXBkYXRlCiAgLSBoZWxtIHJlcG8gYWRkIGFyZ28gaHR0cHM6Ly9hcmdvcHJvai5naXRodWIuaW8vYXJnby1oZWxtCiAgLSBta2RpciAtcCAvaG9tZS9hZG1pbnVzZXIvLmt1YmUKICAtIGNwIC9ldGMvcmFuY2hlci9rM3MvazNzLnlhbWwgL2hvbWUvYWRtaW51c2VyLy5rdWJlL2NvbmZpZwogIC0ga3ViZWN0bCBjcmVhdGUgbnMgYXJnb2NkCiAgLSBoZWxtIHVwZ3JhZGUgLS1rdWJlY29uZmlnIC9ldGMvcmFuY2hlci9rM3MvazNzLnlhbWwgLS1pbnN0YWxsIGRlbW8tYXJnby1jZCBhcmdvL2FyZ28tY2QgLS12ZXJzaW9uIDMuMjYuMTIgLW4gYXJnb2NkCiAgLSBybSAtcmYgL2hvbWUvYWRtaW51c2VyL2xpbnV4LWFtZDY0CiAgLSBjaG93biAtUiBhZG1pbnVzZXI6YWRtaW51c2VyIC9ob21lL2FkbWludXNlci8ua3ViZQogIC0gY2hvd24gYWRtaW51c2VyOmFkbWludXNlciAvaG9tZS9hZG1pbnVzZXIvaGVsbS12My43LjEtbGludXgtYW1kNjQudGFyLmd6Cg=='
var cloudInitStrQuotedBase64 = 'I2Nsb3VkLWNvbmZpZwpwYWNrYWdlX3VwZ3JhZGU6IHRydWUKcGFja2FnZXM6CiAgLSBjdXJsCm91dHB1dDoge2FsbDogJ3wgdGVlIC1hIC92YXIvbG9nL2Nsb3VkLWluaXQtb3V0cHV0LmxvZyd9CnJ1bmNtZDoKICAtIGN1cmwgaHR0cHM6Ly9yZWxlYXNlcy5yYW5jaGVyLmNvbS9pbnN0YWxsLWRvY2tlci8xOC4wOS5zaCB8IHNoCiAgLSB1c2VybW9kIC1hRyBkb2NrZXIgYWRtaW51c2VyCiAgLSBjdXJsIC1zZkwgaHR0cHM6Ly9nZXQuazNzLmlvIHwgc2ggLXMgLSBzZXJ2ZXIgLS10bHMtc2FuIGRlbW8teTRzejdka3Zud2VxNC53ZXN0ZXVyb3BlLmNsb3VkYXBwLmF6dXJlLmNvbQogIC0gdWZ3IGFsbG93IDY0NDMvdGNwCiAgLSB1ZncgYWxsb3cgNDQzL3RjcAogIC0gY3AgL3Zhci9saWIvcmFuY2hlci9rM3Mvc2VydmVyL25vZGUtdG9rZW4gL2hvbWUvYWRtaW51c2VyL25vZGUtdG9rZW4KICAtIGNob3duIGFkbWludXNlcjphZG1pbnVzZXIgL2hvbWUvYWRtaW51c2VyL25vZGUtdG9rZW4KICAtIHNlZCAncy8xMjcuMC4wLjEvZGVtby15NHN6N2Rrdm53ZXE0Lndlc3RldXJvcGUuY2xvdWRhcHAuYXp1cmUuY29tL2cnIC9ldGMvcmFuY2hlci9rM3MvazNzLnlhbWwgPiAvaG9tZS9hZG1pbnVzZXIvazNzLWNvbmZpZwogIC0gY2htb2QgNjAwIC9ob21lL2FkbWludXNlci9rM3MtY29uZmlnCiAgLSBjaG93biBhZG1pbnVzZXI6YWRtaW51c2VyIC9ob21lL2FkbWludXNlci9rM3MtY29uZmlnCiAgLSB3Z2V0IC1jIGh0dHBzOi8vZ2V0LmhlbG0uc2gvaGVsbS12My43LjEtbGludXgtYW1kNjQudGFyLmd6IC1QIC9ob21lL2FkbWludXNlcgogIC0gdGFyIC14dmYgL2hvbWUvYWRtaW51c2VyL2hlbG0tdjMuNy4xLWxpbnV4LWFtZDY0LnRhci5neiAtLWRpcmVjdG9yeSAvaG9tZS9hZG1pbnVzZXIKICAtIG12IC9ob21lL2FkbWludXNlci9saW51eC1hbWQ2NC9oZWxtIC91c3IvbG9jYWwvYmluL2hlbG0KICAtIGhlbG0gcmVwbyBhZGQgc3RhYmxlIGh0dHBzOi8vY2hhcnRzLmhlbG0uc2gvc3RhYmxlCiAgLSBoZWxtIHJlcG8gdXBkYXRlCiAgLSBoZWxtIHJlcG8gYWRkIGFyZ28gaHR0cHM6Ly9hcmdvcHJvai5naXRodWIuaW8vYXJnby1oZWxtCiAgLSBta2RpciAtcCAvaG9tZS9hZG1pbnVzZXIvLmt1YmUKICAtIGNwIC9ldGMvcmFuY2hlci9rM3MvazNzLnlhbWwgL2hvbWUvYWRtaW51c2VyLy5rdWJlL2NvbmZpZwogIC0ga3ViZWN0bCBjcmVhdGUgbnMgYXJnb2NkCiAgLSBoZWxtIHVwZ3JhZGUgLS1rdWJlY29uZmlnIC9ldGMvcmFuY2hlci9rM3MvazNzLnlhbWwgLS1pbnN0YWxsIGRlbW8tYXJnby1jZCBhcmdvL2FyZ28tY2QgLS12ZXJzaW9uIDMuMjYuMTIgLW4gYXJnb2NkCiAgLSBybSAtcmYgL2hvbWUvYWRtaW51c2VyL2xpbnV4LWFtZDY0CiAgLSBjaG93biAtUiBhZG1pbnVzZXI6YWRtaW51c2VyIC9ob21lL2FkbWludXNlci8ua3ViZQogIC0gY2hvd24gYWRtaW51c2VyOmFkbWludXNlciAvaG9tZS9hZG1pbnVzZXIvaGVsbS12My43LjEtbGludXgtYW1kNjQudGFyLmd6CiAgLSBjdXJsIC1zU0wgLW8gL3Vzci9sb2NhbC9iaW4vYXJnb2NkIGh0dHBzOi8vZ2l0aHViLmNvbS9hcmdvcHJvai9hcmdvLWNkL3JlbGVhc2VzL2xhdGVzdC9kb3dubG9hZC9hcmdvY2QtbGludXgtYW1kNjQKICAtIGNobW9kIDc1NSAvdXNyL2xvY2FsL2Jpbi9hcmdvY2QK'

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
      //customData: loadFileAsBase64('cloud-init-k3s-argocd.yml')
      customData: cloudInitStrQuotedBase64
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

// Create user managed identity (to be used by custom deployment script)
resource mi 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: identityName
  location: location
}

resource deploymentScriptCustomRole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' = {
  name: guid(customRoleName, resourceGroup().id)
  properties: {
    roleName: customRoleName
    description: 'Configure least privilege for the deployment principal in deployment script'
    permissions: [
      {
        actions: [
          'Microsoft.Storage/storageAccounts/*'
          'Microsoft.ContainerInstance/containerGroups/*'
          'Microsoft.Resources/deployments/*'
          'Microsoft.Resources/deploymentScripts/*'
          'Microsoft.Storage/register/action'
          'Microsoft.ContainerInstance/register/action'
        ]
      }
    ]
    assignableScopes: [
      resourceGroup().id
    ]
  }    
}

resource miCustomRoleAssign 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(customRoleName, identityName, resourceGroup().id)
  properties: {
      roleDefinitionId: deploymentScriptCustomRole.id
      principalId: mi.properties.principalId
      principalType: 'ServicePrincipal'
  }
}

resource generateCloudInitDeploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'createCloudInit'
  location: resourceGroup().location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      'mi.id': {}
    }
  }
  properties: {
    azCliVersion: '2.24.0'
    environmentVariables: [
      {
        name: 'RANCHER_DOCKER_INSTALL_URL'
        value: 'https://releases.rancher.com/install-docker/18.09.sh'
      }
      {
        name: 'LINUX_ADMIN_USERNAME'
        value: linuxAdminUsername
      }
      {
        name: 'HELM_TAR_BALL'
        value: 'helm-v3.7.1-linux-amd64.tar.gz'
      }
      {
        name: 'ARGOCD_VERSION'
        value: '3.26.12'
      }
      {
        name: 'ARGOCD_NAMESPACE'
        value: 'argocd'
      }
      {
        name: 'HOST_IP_ADDRESS'
        value: publicIP.properties.dnsSettings.fqdn
      }
    ]
    storageAccountSettings: {
      storageAccountName: storageAccountName
      storageAccountKey: listKeys(resourceId('Microsoft.Storage/storageAccounts', storageAccountName), '2021-04-01').keys[0].value
    }
    primaryScriptUri: 'https://raw.githubusercontent.com/pelleo/Hybrid.IoTHub.Deployment/main/deployment/bicep/modules/create_cloud_init_input_bicep.sh'
    supportingScriptUris: [
      'https://raw.githubusercontent.com/pelleo/Hybrid.IoTHub.Deployment/main/deployment/bicep/modules/create_cloud-init-template.yml'
    ]
    timeout: 'PT30M'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
  }
}

output cloudInitFileAsBase64 string = generateCloudInitDeploymentScript.properties.outputs.cloudInitFileAsBase64
//output publicIpAddress string = publicIP.properties.ipAddress
output fqdn string = publicIP.properties.dnsSettings.fqdn
