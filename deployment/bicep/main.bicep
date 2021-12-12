targetScope = 'subscription'

// Global parameters.  Provide default values as appropriate
@description('Resource group that will host OPC Azure test resources')
param resourceGroupName string

@description('Resource group that will simulate onpremises resources')
param onpremResourceGroupName string

@description('The type of environment. This must be test or prod.')
@allowed([
  'dev'
  'test'
  'prod'
])
param environmentType string

@description('The Azure region into which the resources should be deployed.')
param location string = deployment().location

@allowed([
  'yes'
  'no'
])
@description('Conditional AKS deployment.  Must be yes or no.')
param aksDeployment string

@allowed([
  'yes'
  'no'
])
@description('Conditional IoT deployment.  Must be yes or no.')
param iotDeployment string

@allowed([
  'yes'
  'no'
])
@description('Conditional VM deployment.  Must be yes or no.')
param vmDeployment string

@allowed([
  'yes'
  'no'
])
@description('Conditional DPS deployment.  Must be yes or no.')
param dpsDeployment string

@description('URI of the cloud init script used by Bicep deployment script.  Support is currently limited to public repos only')
param  cloudInitScriptUri string = 'https://raw.githubusercontent.com/pelleo/Hybrid.IoTHub.Deployment/main/deployment/bicep/modules/create_cloud_init_input_string_bicep.sh'

@description('Public SSH key used by VMs and VMSS')
param sshRSAPublicKey string = 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCsjYzxGD3DuHdin5WShA4/GMF53+0QVjCsV9dJgXrt2INF5T8LX+Gu7tFXHcKOhqkoRzqNC+jYGdEkUFqNmKtZZ0S/DflUVt+DvM7jukY/++f57UZdw1mWDtxxCK5CYg5tOzAJQC7h9YhUxaXUOTJ/uFQvm5628sIR3Id27qarV07oi56gJyD6/6AVBQWsthB8Qwif6KQdHHzH0ZW1AF5W1HVg0OGgFBsiFLQx6uQGCCQGSiyjPsM6s0UqlTvbiXbrZ0LHj+DGQp6leeZghblOw4O5jYWfIBgO1+ioVToc0U8TRuQCqerueLDH9NZxObRBpA53NTUfKf3auOgOob7l pelleo@PELLEOPC'

@description('DNS label prefix used by VMs and AKS resources')
param dnsLabelPrefix string = 'demo'

// Default parameter values for AKS infrastructure
param clusterName string = 'demo-aks'
param aksClientId string
param aksClientSecret string
param osDiskSizeGB int = 0
param agentCount int = 1
param agentVMSize string = 'standard_d4s_v3'
param linuxAdminUsername string = 'adminuser'

// Default parameter values for storage account
param storageAccountNamePrefix string = 'demostore'
param fileShareName string = 'demoshare'
param fileShareType string

// Default parameter values for IoT infrastructure
param iotHubNamePrefix string = 'demo-iothub'
param iotStorageAccountNamePrefix string = 'demoiotstore'
param provisioningServiceNamePrefix string = 'demo-dps'
param iotSkuName string = 'S1'
param iotSkuUnits int = 1

// Default parameter values for VM infrastructure
param vmName string = 'demo-vm'
param vmSize string = 'standard_d4s_v3'
param vmStorageAccountNamePrefix string = 'onpremstore'

// Fix version and correct time format later
param tags object = {
    owner: 'pelleo@microsoft.com'
    project: 'Hybrid.IoTHub'
    version:  '1.0'
    timestamp: utcNow()
    env: environmentType
}
var additionalAksTags = {
  'service': 'virtualaks'
}
var aksTags = union(tags, additionalAksTags)

var deployAks = (aksDeployment == 'yes') ? true : false
var deployIot = (iotDeployment == 'yes') ? true : false
var deployVm = (vmDeployment == 'yes') ? true : false

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: resourceGroupName
  location: deployment().location
  tags: tags
}

resource onpremResourceGroup 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: onpremResourceGroupName
  location: deployment().location
  tags: tags
}

// Modules
module aksinfra './modules/aks-infra.bicep' = if (deployAks) {
  scope: resourceGroup
  name: 'aks-infra-${location}'
  params: {
    location: location
    environmentType: environmentType
    clusterName: clusterName
    aksClientId: aksClientId
    aksClientSecret: aksClientSecret
    dnsLabelPrefix: dnsLabelPrefix
    osDiskSizeGB: osDiskSizeGB
    agentCount: agentCount
    agentVMSize: agentVMSize
    linuxAdminUsername: linuxAdminUsername
    sshRSAPublicKey: sshRSAPublicKey
    storageAccountNamePrefix: storageAccountNamePrefix
    fileShareName: fileShareName
    fileShareType: fileShareType
    tags: aksTags
  }
}

module iotinfra './modules/iot-infra.bicep' = if (deployIot) {
  scope: resourceGroup
  name: 'iot-infra-${location}'
  params: {
    location: location
    iotHubNamePrefix: iotHubNamePrefix
    storageAccountNamePrefix: iotStorageAccountNamePrefix
    provisioningServiceNamePrefix: provisioningServiceNamePrefix
    iotSkuName: iotSkuName
    iotSkuUnits: iotSkuUnits
    dpsDeployment: dpsDeployment
    tags: tags
  }
}

module  vminfra './modules/vm-infra.bicep' = if (deployVm) {
  scope: onpremResourceGroup
  name: 'vm-infra-${location}'
  params: {
    location: location
    vmName: vmName
    vmSize: vmSize
    storageAccountNamePrefix: vmStorageAccountNamePrefix
    fileShareName: fileShareName
    fileShareType: fileShareType
    environmentType: environmentType
    linuxAdminUsername: linuxAdminUsername
    sshRSAPublicKey: sshRSAPublicKey
    dnsLabelPrefix: dnsLabelPrefix
    cloudInitScriptUri: cloudInitScriptUri
    tags: tags
  }
}

// Outputs
output aksStorageAccountName string = aksinfra.outputs.storageAccountName
output iotHubName string = iotinfra.outputs.iotHubName
output iotStorageAccountName string = iotinfra.outputs.storageAccountName
output cloudInitFileAsBase64 string = vminfra.outputs.cloudInitFileAsBase64
//output publicIpAddress string = vminfra.outputs.publicIpAddress
output fqdn string = vminfra.outputs.fqdn
