#/bin/bash
set -euo pipefail

# Path to public key must be specified for each user.
SSH_KEY_PATH=/home/pelleo/.ssh/id_rsa.pub

# File that holds config commands to be executed by cloud-init.
CLOUD_INIT_PATH=../deployment/bicep/modules/cloud-init-k3s-argocd.yml

# Values must agree with those used by bicep.
LOCATION=westeurope                     # pipeline parameter
RESOURCE_GROUP_NAME=rg-onprem-demo      # pipeline parameter
ADMIN_USERNAME=adminuser                # main.bicep
VM_NAME=demo-vm                         # main.bicep
VM_SIZE=standard_d4s_v3                 # main.bicep
PUBLISHER=Canonical                     # vm-infra.bicep
OFFER=UbuntuServer                      # vm-infra.bicep
SKU=18.04-LTS                           # vm-infra.bicep
VERSION=latest                          # vm-infra.bicep
NETWORK_INTERFACE_NAME=${VM_NAME}-nic   # vm-infra.bicep

# Existing resource group and NIC assumed.
az vm create -l ${LOCATION} \
             -g ${RESOURCE_GROUP_NAME} \
             -n ${VM_NAME} \
             --image ${PUBLISHER}:${OFFER}:${SKU}:${VERSION} \
             --size ${VM_SIZE} \
             --admin-username ${ADMIN_USERNAME} \
             --authentication-type ssh \
             --ssh-key-values ${SSH_KEY_PATH} \
             --nics ${NETWORK_INTERFACE_NAME} \
             --custom-data ${CLOUD_INIT_PATH}
