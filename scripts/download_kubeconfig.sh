#/bin/bash
set -euo pipefail

# Login information for Azure VM hosting Argo CD service.
SERVER=demo-y4sz7dkvnweq4.westeurope.cloudapp.azure.com
ADMIN_USERNAME=adminuser

# Default local kubeconfig directory.
KUBECONFIG_DIR=/c/Users/pelleo/.kube

# AKS cluster info.
AKS_RG_NAME=rg-aks-demo
AKS_CLUSTER_NAME=demo-aks

# Repository information.
REPO_NAME=Hybrid.IoTHub.Deployment

# Get path to current script. Use below syntax rather than SCRIPTPATH=`pwd` 
# for proper handling of edge cases like spaces and symbolic links.
SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
LOCAL_PARENT_DIR=${SCRIPT_PATH%%${REPO_NAME}*}
LOCAL_REPO_ROOT=${LOCAL_PARENT_DIR}/${REPO_NAME}

# Navigate to script dir.  Download kubeconfig and node token from VM.
ssh-keygen -f ${HOME}/.ssh/known_hosts -R ${SERVER}
scp -i ${LOCAL_REPO_ROOT}/local/.ssh/id_rsa -o "StrictHostKeyChecking no" ${ADMIN_USERNAME}@${SERVER}:k3s-config ${LOCAL_REPO_ROOT}/local
scp -i ${LOCAL_REPO_ROOT}/local/.ssh/id_rsa -o "StrictHostKeyChecking no" ${ADMIN_USERNAME}@${SERVER}:node-token ${LOCAL_REPO_ROOT}/local

# WSL fix. Must copy the new kubeconfig to default WSL location.
mv ${KUBECONFIG_DIR}/config ${KUBECONFIG_DIR}/config${RANDOM}.bak           # Backup existing kubeconfig
cp ${LOCAL_REPO_ROOT}/local/k3s-config ${KUBECONFIG_DIR}/config

# Merge AKS cluster kubeconfig into default config store.
az aks get-credentials -g ${AKS_RG_NAME} -n ${AKS_CLUSTER_NAME}