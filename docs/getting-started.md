# General client workstation requirements
You will need a bash client (native Linux or WSL2) with the following software installed:

- Az CLI
- Docker
- Kubernetes (kubectl)
- Git
- Bicep
- Helm
- Argo CD CLI
- Standard bash utilities such as `ssh`, `ssh-keygen`, `scp` and `jq`

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

# Create SSH key pair
We will generate an SSH key pair specifically for logging to the AKS and K3s host VMs in Azure. via SSH  Navigate to the `scripts` directory.  Run
```
$ ./create_ssh_key_pair.sh
```
Leave the input empty when prompted for a password.  This will create a private and a public key in the `local/.ssh` directory.

**Note:**  The `local` folder and its subfolders are not uploaded to GitHub.

# Create GitHub secrets
If not already logged in to GitHub, do so now and navigate to the recently forked repository.  Select `Settings` from the horizontal menu and then `Secrets`.  Create the following secrets:
```
Name: AZURE_CREDENTIALS      Value: ${sdk_auth}                                # Entire JSON output from SP creation
Name: AKS_CLIENT_ID          Value: ${client_id}
Name: AKS_CLIENT_SECRET      Value: ${client_secret}
Name: SSH_RSA_PUBLIC_KEY     Value: echo \'$(cat ${LOCAL_REPO_ROOT}/local/.ssh/id_rsa.pub)\'    
Name: CLOUD_INIT_SCRIPT_URI  Value: https://raw.githubusercontent.com/<your_username>/Hybrid.IoTHub.Deployment/main/deployment/bicep/modules/create_cloud_init_input_string_bicep.sh
```

Replace `<your_username>` with your actual GitHub username.  The URI must point to the cloud-init script file.

**Note:** Your SSH key pair must exist and be stored in its default location (`~/.ssh/id_rsa.pub`) prior to creating the GitHub secret `SSH_RSA_PUBLIC_KEY`.

# Set up GitHub Actions workflow
First time configuration of Git Actions:
- Copy the contents of `Hybrid.IoTHub.Deployment/.github/workflows/main.yml` to the clipboard
- Select `Actions` from the menu at the top of the page and then `New workflow`.  Follow the `set up a workflow yourself` link
- Remove the boiler plate code and paste the copied contents into `main.yaml`
- Commit the changes directly to `main`

Synchronize the local Git repository with the GitHub origin if necessary.  At this point you should have a fully functional Git Actions pipeline.  The remaining environment variables can be left at their default values; they are used to control the behavior of the bicep templates that build the K8s infrastructure and supporting resources.

For general infromation on Git Actions, please see https://docs.github.com/en/actions

# Execute GitHub actions workflow
Select `Actions` from the menu at the top of the page and highlight `IoTHub Infrastructure Deployment` to launch the workflow.  Wait until the workflow terminates.  

# Download kubeconfig
Wait until the workflow has terminated successfully.
- Open the workflow logs and drill down into the `Create IoT Hub Infrastructure` step
- Scroll down the logs and look for the `outputs:` key.
- Copy the `fqdn` value.  Save for later use (it will be needed when configuring Argo CD for first time use)
- Navigate to the `${REPO_ROOT}/scripts` directory and open `download_kubeconfig.sh` in a text editor
- Set the following variables:
  ```
  SERVER=<Copied FQDN of K3s host>
  KUBECONFIG_DIR=<Full path to default kubeconfig directory>
  ```
  Typical`KUBECONFIG_DIR` values include `/c/Users/<username>/.kube` or `/mnt/c/Users/<username>/.kube` for a WSL based environment.  For native Linux the default location is `~/.kube`
- Run
  ```
  $ ./download_kubeconfig.sh
  ```
  If you get the message `scp: k3s-config: No such file or directory`, wait a moment and rerun the command.
- Verify cluster access
  ```
  kubectl config get-contexts -o name
  kubectl config use-context default
  kubectl get nodes
  kubectl config use-context demo-aks
  kubectl get nodes
  ```

**Note:**  `download_kubeconfig.sh` will make a backup of the original kubeconfig file (`config<random>.bak`) and then overwrite the existing default kubeconfig file.  To restore the original `config` file, simply run `mv ${KUBECONFIG_DIR}/config<random>.bak  ${KUBECONFIG_DIR}/config` 

**Note:**  `download_kubeconfig.sh` uses the `scp` option `StrictHostKeyChecking no`.  This is not recommended practice, but is used in this demo environment to suppress manual host confirmation to simplify download automation of kubeconfig.

**Note:**  Editing `download_kubeconfig.sh` is needed only the first time the GitHub workflow is executed.  As long as the K3s resource group ID remains the same, the FQDN will not change.  This remark applies even to the case where the resource groups are deleted completely.
