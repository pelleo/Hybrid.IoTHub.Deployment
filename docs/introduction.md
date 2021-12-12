# General client workstation requirements
You will need a bash client (native Linux or WSL2) with the following software installed:

- Az CLI
- Docker
- Kubernetes (kubectl)
- Git
- Bicep
- Helm
- Argo CD CLI
- Standard bash scripting tools such as `jq`

# Initial setup
Before setting up the project, make sure that you are logged-in to Azure with owner/contributor rights on the associated subscription.  
```
az login

# Verify subscription.
account=$(az account list --query "[?isDefault]")
echo ${account} | jq

# Change subscription if necessary.
az account set -s <your subscription name>

# Save subscription ID and tenant ID for future reference.
account=$(az account list --query "[?isDefault]")
subscription_id=$(echo ${account} | jq -r '.[].id')
tenant_id=$(echo ${account} | jq -r '.[].tenantId')
echo ${subscription_id}
echo ${tenant_id}
```

# Get the code
Log in to your GitHub account and make a fork of the [Hybrid.IoTHub.Deployment](https://github.com/pelleo/Hybrid.IoTHub.Deployment) repo to your own account.  The top level structure should look something like
```
.github/workflows
├── clusters
├── deployment/bicep
├── docs
├── local
├── README.md
└── scripts
```
Clone the forked repository to your local workstation.

# Create Service Principal
In order for the pipeline and the AKS cluster to function properly it is necessary to create a service principal.  This service principal (SP) will serve as a "catch all" whenever there is a need for a service principal.  It will be granted owner/contributor rights at the subscription level.  *It is strongly advised not to create this service principal in a subscription that is used for production purposes*.  Note the `--sdk-auth` switch in the SP creation command.  It is used to output the SP credentials in format that is needed when setting up Git Actions.
```
# Create service principal for Azure authentication (output is compatible with Azure SDK auth file).
sdk_auth=$(az ad sp create-for-rbac --role Owner --sdk-auth)

# Copy the entire JSON output to a scratch pad as it will be required when setting up Git Actions.
echo ${sdk_auth} | jq

# Record client ID and client secret.  This will be used when assigning an SP to the AKS service.
client_id=$(echo ${sdk_auth} | jq -r '.clientId')
client_secret=$(echo ${sdk_auth} | jq -r '.clientSecret')
echo ${client_id}
echo ${client_secret}
```

# Create GitHub secrets
If not already logged in to GitHub, do so now and navigate to the recently forked repository.  Select `Settings` from the horizontal menu and then `Secrets`.  Create the following secrets:
```
Name: AKS_CLIENT_ID         Value: ${client_id}
Name: AKS_CLIENT_SECRET     Value: ${client_secret}
Name: AZURE_CREDENTIALS     Value: ${sdk_auth}         # Entire JSON output from SP creation
```

# Set up GitHub Actions workflow
First time configuration of Git Actions:
- Copy the contents of `Hybrid.IoTHub.Deployment/.github/workflows/main.yml` to the clipboard
- Select `Actions` from the menu at the top of the page and then `New workflow`.  Follow the `set up a workflow yourself` link
- Paste the copied contents into `main.yaml`
- Commit the changes directly to `main`

Synchronize the local Git repository with the GitHub origin if necessary.  At this point you should have a fully functional Git Actions pipeline.  The remaining environment variables can be left at their default values; they are used to control the behavior of the bicep templates that build the K8s infrastructure and supporting resources.

For general infromation on Git Actions, please see https://docs.github.com/en/actions
