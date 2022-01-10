#!/bin/bash

set -eo pipefail

# Used only for pruning path to repository root.  Should be 
# regarded as a local constant unless project is renamed.
repo_name=Hybrid.IoTHub.Deployment

# Silently continue if env var does not exist.
local_repo_root=${GITHUB_WORKSPACE}

# Use location of current script to get local repo root if not executed by GitHub build agents.
if [[ -z ${local_repo_root} ]]; then
    # Use below syntax rather than script_path=`pwd` for proper 
    # handling of edge cases like spaces and symbolic links.
    script_path="$(cd -- "$(dirname "${0}")" >/dev/null 2>&1; pwd -P)"
    #local_parent_dir=${script_path%${repo_name}*}
    #local_repo_root=${local_parent_dir}/${repo_name}
    local_repo_root=${script_path%${repo_name}*}${repo_name}
fi

echo
echo Local repo root:
echo ${local_repo_root}
echo

mkdir -p ${local_repo_root}/local/.ssh
chmod 700 ${local_repo_root}/local/.ssh

# Generate SSH key pair to be used for accessing K3s host.
ssh-keygen -t rsa -b 2048 -N '' -f ${local_repo_root}/local/.ssh/id_rsa <<<y -C "k8s_host_key"

# Store private key in format that allows it to be genereted in standard
# multiline format when retrieved from GitGub secrets (or any env var).
awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' ${local_repo_root}/local/.ssh/id_rsa > ${local_repo_root}/local/.ssh/id_rsa_github_secret
