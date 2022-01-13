#!/bin/bash

set -eo pipefail

# Used only for pruning path to repository root.  Should be 
# regarded as a local constant unless project is renamed.
repo_name=Hybrid.IoTHub.Deployment

# Set GitHub username to locally defined env var GIT_HUB_USERNAME if running 
# script locally; otherwise use predefined GitHub variable GITHUB_ACTOR.
[[ -z ${GITHUB_ACTOR+x} ]]  && github_actor=${GIT_HUB_USERNAME}  || github_actor=${GITHUB_ACTOR} 

# This URI must point to the cloud-init script in your GitHub repo.
cloud_init_script_uri=https://raw.githubusercontent.com/${github_actor}/Hybrid.IoTHub.Deployment/main/deployment/bicep/modules/create_cloud_init_input_string_bicep.sh

# Silently continue if env var does not exist.
local_repo_root=${GITHUB_WORKSPACE}

# Use location of current script to get local repo root if not executed by GitHub build agents.
if [[ -z ${local_repo_root} ]]; then
    # Use below syntax rather than script_path=`pwd` for proper 
    # handling of edge cases like spaces and symbolic links.
    script_path="$(cd -- "$(dirname "${0}")" >/dev/null 2>&1; pwd -P)"
    local_repo_root=${script_path%${repo_name}*}${repo_name}
fi

echo
echo "Upgrading bicep ..."
az bicep upgrade

echo "Creating Azure resources ..."
echo
az deployment sub create \
    --name AKS_IoT_K3S_deploy \
    --location ${LOCATION} \
    --template-file ${local_repo_root}/deployment/bicep/main.bicep \
    --parameters resourceGroupName=${AKS_RG_NAME} \
                 onpremResourceGroupName=${K3S_RG_NAME} \
                 environmentType=dev \
                 aksDeployment=yes \
                 iotDeployment=yes \
                 vmDeployment=yes \
                 aksClientId=${AKS_CLIENT_ID} \
                 aksClientSecret=${AKS_CLIENT_SECRET} \
                 fileShareType=SMB \
                 dpsDeployment=no \
                 cloudInitScriptUri=${cloud_init_script_uri} \
                 sshRSAPublicKey="${SSH_RSA_PUBLIC_KEY}"

echo
echo "Saving Bicep deployment outputs ..."
echo
az deployment sub show \
    --name AKS_IoT_K3S_deploy \
    --query properties.outputs > ${local_repo_root}/local/deployment-output.txt
