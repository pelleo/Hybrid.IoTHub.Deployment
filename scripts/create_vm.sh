#/bin/bash
set -euo pipefail

# Path to public key must be specified for each user.
sshKeyPath=/home/pelleo/.ssh/id_rsa.pub

# Values must agree with those used by bicep.
location=westeurope                  # pipeline parameter
resourceGroupName=rg-onprem-demo     # pipeline parameter
linuxAdminUsername=adminuser         # main.bicep
vmName=demo-vm                       # main.bicep
vmSize=standard_d4s_v3               # main.bicep
publisher=Canonical                  # vm-infra.bicep
offer=UbuntuServer                   # vm-infra.bicep
sku=18.04-LTS                        # vm-infra.bicep
version=latest                       # vm-infra.bicep
networkInterfaceName=${vmName}-nic   # vm-infra.bicep

# Existing resource group and NIC assumed.
az vm create -l ${location} \
             -g ${resourceGroupName} \
             -n ${vmName} \
             --image ${publisher}:${offer}:${sku}:${version} \
             --size ${vmSize} \
             --admin-username ${linuxAdminUsername} \
             --authentication-type ssh \
             --ssh-key-values ${sshKeyPath} \
             --nics ${networkInterfaceName} \
             --custom-data cloud-init.txt
