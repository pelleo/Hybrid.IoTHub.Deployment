#!/bin/bash
set -euo pipefail

# Replace placeholders in cloud-init-template.yml by real values.  See
# https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/deployment-script-bicep#work-with-outputs-from-cli-script
# for information on how output of CLI scripts is handled.  In particular,
# Output must always be stored in the AZ_SCRIPTS_OUTPUT_PATH (built-in) location 
# and it must be a valid JSON string object.

sed "s/%%RANCHER_DOCKER_INSTALL_URL%%/${RANCHER_DOCKER_INSTALL_URL}/g; \
     s/%%LINUX_ADMIN_USERNAME%%/${LINUX_ADMIN_USERNAME}/g; \
     s/%%HELM_TAR_BALL%%/${HELM_TAR_BALL}/g; \
     s/%%ARGOCD_VERSION%%/${ARGOCD_VERSION}/g; \
     s/%%ARGOCD_NAMESPACE%%/${ARGOCD_NAMESPACE}/g; \
     s/%%HOST_IP_ADDRESS_OR_FQDN%%/${HOST_IP_ADDRESS_OR_FQDN}/g; \
     " cloud-init-template.yml | base64 | tr -d '\n\r' |  awk '{printf "{\"cloudInitFileAsBase64\": \"%s\"}", $1}' > ${AZ_SCRIPTS_OUTPUT_PATH}
