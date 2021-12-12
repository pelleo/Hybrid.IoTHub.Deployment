#!/bin/bash

set -euo pipefail

# From https://docs.microsoft.com/en-us/azure/container-instances/container-instances-github-action

az login

# Set account.
az account set -s pelleo
account=$(az account list --query "[?isDefault]")
echo ${account} | jq

# Create resource group
location=westeurope
rg_name=rg-gitactions
group=$(az group create -n ${rg_name} -l ${location})
echo ${group} | jq 
rg_id=$(echo ${group} | jq -r '.id')

# Create service principal for Azure authentication (output is compatible with Azure SDK auth file).
sdk_auth=$(az ad sp create-for-rbac --scope ${rg_id} --role Contributor --sdk-auth)

# Update service principal for registry authentication (AcrPush gives push and pull).
acr_name=pelleo
registry=$(az acr show -g ${rg_name} -n ${acr_name})
echo ${registry} | jq
registry_id=$(echo ${registry} | jq -r '.id')
registry_login_server=$(echo ${registry} | jq -r '.loginServer')
echo ${echo $registry_id}
client_id=$(echo ${sdk_auth} | jq -r '.clientId')
client_secret=$(echo ${sdk_auth} | jq -r '.clientSecret')
echo ${acr_role_assignment} | jq
acr_role_assignment=$(az role assignment create --assignee ${client_id} --scope ${registry_id} --role AcrPush)

# Save credentials to GitHub repo
# 1.  In the GitHub UI, navigate to your forked repository and select Settings > Secrets.
# 2.  Select Add a new secret to add the following secrets:

# Secret 	                Value
# AZURE_CREDENTIALS 	    The entire JSON output from the service principal creation step ${sdk_auth}
# REGISTRY_LOGIN_SERVER 	The login server name of your registry (all lowercase). Example: myregistry.azurecr.io
# REGISTRY_USERNAME 	    The clientId from the JSON output from the service principal creation
# REGISTRY_PASSWORD 	    The clientSecret from the JSON output from the service principal creation
# RESOURCE_GROUP 	        The name of the resource group you used to scope the service principal

echo ${sdk_auth} | jq
{
  "clientId": "535ace18-0b2b-4da6-8460-59119b0a3050",
  "clientSecret": "q_cqeFY_nggsSPZ.UEszUZVxr6S1JL5XCA",
  "subscriptionId": "b0a87f63-43b1-483a-b3c7-03b1e2a68a9c",
  "tenantId": "72f988bf-86f1-41af-91ab-2d7cd011db47",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}

echo ${registry_login_server}
pelleo.azurecr.io

echo ${client_id}
535ace18-0b2b-4da6-8460-59119b0a3050

echo ${client_secret}
q_cqeFY_nggsSPZ.UEszUZVxr6S1JL5XCA

echo ${rg_name}
rg-gitactions

# Execute workflow.  Display result upon completion.
az container show \
  --resource-group ${rg_name} \
  --name aci-sampleapp \
  --query "{FQDN:ipAddress.fqdn,ProvisioningState:provisioningState}" \
  --output table

