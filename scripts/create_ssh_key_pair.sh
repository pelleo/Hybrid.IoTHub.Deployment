#!/bin/bash

set -euo pipefail

# Repository information.
REPO_NAME=Hybrid.IoTHub.Deployment

# Get path to current script. Use below syntax rather than SCRIPTPATH=`pwd` 
# for proper handling of edge cases like spaces and symbolic links.
SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
LOCAL_PARENT_DIR=${SCRIPT_PATH%%${REPO_NAME}*}
LOCAL_REPO_ROOT=${LOCAL_PARENT_DIR}/${REPO_NAME}

mkdir -p ${LOCAL_REPO_ROOT}/local/.ssh
chmod 700 ${LOCAL_REPO_ROOT}/local/.ssh

# Generate SSH key pair to be used for accessing K3s host.
ssh-keygen -t rsa -b 2048 -f ${LOCAL_REPO_ROOT}/local/.ssh/id_rsa -C "k8s_host_key"

# Store private key in format that allows it to be genereted in standard
# multiline format when retrieved from GitGub secrets (or any env var).
awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' ${LOCAL_REPO_ROOT}/local/.ssh/id_rsa > ${LOCAL_REPO_ROOT}/local/.ssh/id_rsa_github_secret
