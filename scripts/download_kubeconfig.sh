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

# File path of kubeconfig on remote K3s host
FILE_PATH=/home/${ADMIN_USERNAME}/k3s-config

# Remove old entries from known hosts.
ssh-keygen -f ${HOME}/.ssh/known_hosts -R ${SERVER}

# Monitor creation of k3s-config.
FILE_EXISTS=no
n=24
for (( i=1; i<=n; i++ ))
do  
    echo ""
    echo "Checking if ${SERVER}:${FILE_PATH} exists ${i} times out of ${n} ..."
    echo ""
    sleep 10
    
    # Test if there are containers still not ready
    FILE_EXISTS=$(ssh -q -i ${LOCAL_REPO_ROOT}/local/.ssh/id_rsa \
        -o "StrictHostKeyChecking no" \
        ${ADMIN_USERNAME}@${SERVER} \
        [[ -f ${FILE_PATH} ]] && echo yes || echo no;)

    # Exit loop if file exists ("control statement form").
    [[ "${FILE_EXISTS}" == "yes" ]] && break
done

# Exit script if file not found.
if [[ ${FILE_EXISTS} == "no" ]]; then
    echo "File ${SERVER}:${FILE_PATH} not found"
    exit
fi

# File exists, download kubeconfig and node token from VM.
echo ""
echo "Downloading  ${SERVER}:${FILE_PATH} to ${LOCAL_REPO_ROOT}/local ..."
echo ""
sleep 5
scp -i ${LOCAL_REPO_ROOT}/local/.ssh/id_rsa -o "StrictHostKeyChecking no" ${ADMIN_USERNAME}@${SERVER}:k3s-config ${LOCAL_REPO_ROOT}/local
scp -q -i ${LOCAL_REPO_ROOT}/local/.ssh/id_rsa -o "StrictHostKeyChecking no" ${ADMIN_USERNAME}@${SERVER}:node-token ${LOCAL_REPO_ROOT}/local

# WSL fix. Must copy the new kubeconfig to default WSL location.
echo ""
echo "Merging K3s demo cluster kubeconfig ..."
mv ${KUBECONFIG_DIR}/config ${KUBECONFIG_DIR}/config${RANDOM}.bak           # Backup existing kubeconfig
cp ${LOCAL_REPO_ROOT}/local/k3s-config ${KUBECONFIG_DIR}/config

# Merge AKS cluster kubeconfig into default config store.
echo "Merging AKS demo cluster kubeconfig ..."
echo ""
az aks get-credentials -g ${AKS_RG_NAME} -n ${AKS_CLUSTER_NAME}