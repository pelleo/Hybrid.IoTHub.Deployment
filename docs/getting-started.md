# General client workstation requirements
The instructions below describe how run the `Hybrid.IoTHub.Deployment` sample from a bash client (native Linux or WSL2).  It is not recommended to use a Windows/PowerShell client.  You will need the following software installed:

- Az CLI
- Docker client
- Kubernetes (kubectl)
- Git
- Bicep
- Helm
- Argo CD CLI
- Bash utilities such as `ssh`, `ssh-keygen`, `scp` and `jq`

This sample has been developed using Ubuntu 20.04.2 LTS running on WSL2.  Az CLi version is 2.25.0.

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
To be able to communicate with your GitHub repository you need to create a [personal access token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token).  For this sample, check all scopes and permissions.  Set the validity period to 90 days.

Open a bash client and clone the forked repository to your local workstation:
```
# Navigate to home directory.
$ cd

# Create a directory in which you want to create local copy of your forked repo.
$ mkdir -p repos
$ cd repos
$ git clone https://github.com/<your_username>/Hybrid.IoTHub.Deployment.git
```
Substitute `<your_username>` with your actual GitHub username.  When prompted, enter your GitHub username.  For password, use your recently created personal access token.

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
**Note:** Do not close this terminal window, since the shell variables will be needed when configuring GitHub secrets.

# Create SSH key pair
We will generate an SSH key pair specifically for logging in to the AKS and K3s host VMs in Azure via SSH. Navigate to the `scripts` directory.  Run
```
$ ./create_ssh_key_pair.sh
```
Leave the input empty when prompted for a password.  This will create a private and a public key in the `local/.ssh` directory.

**Note:**  The `local` folder and its subfolders are not uploaded to GitHub.

# Create GitHub secrets
If not already logged in to GitHub, do so now and navigate to the recently forked repository.  The following GitHub secrets must be created:
- `AZURE_CREDENTIALS`
- `AKS_CLIENT_ID`
- `AKS_CLIENT_SECRET`
- `SSH_RSA_PUBLIC_KEY` 
- `CLOUD_INIT_SCRIPT_URI`

Before actually creating the GitHub secrets, make sure that you have the requisite information available by copying the output of the following commands:
```
# Get value for AZURE_CREDENTIALS. Be sure to collect entire JSON object.
echo ${sdk_auth} | jq

# Get value for AKS_CLIENT_ID
echo ${client_id}

# Get value for AKS_CLIENT_SECRET
echo ${client_secret}
```

The value of `SSH_RSA_PUBLIC_KEY` is available in `<your_local_repository_root>/local/.ssh/id_rsa.pub`.  If you created the `repos` folder in your bash home directory you can obtain the value as
```
echo \'$(cat ~/repos/Hybrid.IoTHub.Deployment/local/.ssh/id_rsa.pub)\'
```
If you cloned the sample to a different location, make sure to use the proper path for `<your_local_repository_root>`

To create the secrets, select `Settings` from the horizontal GitHub menu and then `Secrets`.  In turn, create:
- Name: `AZURE_CREDENTIALS`
  - Value: Paste in the saved copy of `${sdk_auth}`
- Name: `AKS_CLIENT_ID`          
  - Value: Paste in the saved copy of `${client_id}`
- Name: `AKS_CLIENT_SECRET`      
  - Value: Paste in the saved copy of `${client_secret}`
- Name: `SSH_RSA_PUBLIC_KEY`     
  - Value: Paste in the contents of `<your_local_repository_root>/local/.ssh/id_rsa.pub`   
- Name: `CLOUD_INIT_SCRIPT_URI`  
  - Value: `https://raw.githubusercontent.com/<your_username>/Hybrid.IoTHub.Deployment/main/deployment/bicep/modules/create_cloud_init_input_string_bicep.sh`

Be sure to replace `<your_username>` and `<your_local_repository_root>` with the proper values.  The URI must point to the cloud-init script file.

**Note:** DO NOT forget the surrounding single quotes (`'`) when pasting the public SSH key.  Failure to do so will invariably lead to SSH login errors.

# First-time setup of GitHub Actions workflow
First-time configuration of Git Actions:
- Copy the contents of `Hybrid.IoTHub.Deployment/.github/workflows/main.yml` to the clipboard.  Save the copy.
- Delete `Hybrid.IoTHub.Deployment/.github/workflows/main.yml`.  It will be recreated as part of the first-time workflow setup
- Select `Settings` from the menu at the top of the page and then `Actions`
  - Check `Allow all actions` and then `Save`
- Select `Actions` from the menu at the top of the page and then `New workflow`
  - Follow the `set up a workflow yourself` link.  This will bring up a workflow template `.gitignore/workflows/main.yml`
- Remove the boiler plate code and paste the previously copied contents into the `<> Edit new file` pane
- Commit the changes directly to `main`

At this point you should have a fully functional Git Actions pipeline.  The remaining environment variables can be left at their default values; they are used to control the behavior of the bicep templates that build the K8s infrastructure and supporting resources.

If needed, synchronize your local repository with the origin.

# Execute GitHub Actions workflow
Select `Actions` from the menu at the top of the page and highlight `IoTHub Infrastructure Deployment` to launch the workflow.  Wait until the workflow terminates.  

For general infromation on Git Actions, please see https://docs.github.com/en/actions

# Download kubeconfig
Wait until the workflow has terminated successfully.
- Open the workflow logs and drill down into the `Create IoT Hub Infrastructure` step
- Scroll down the logs and look for the `outputs:` key.
- Copy the `fqdn` value.  The FQDN should look similar to `demo-y4sz7dkvnweq4.westeurope.cloudapp.azure.com`.
- Open a bash shell and set the following environment variables:
  ```
  $ cd <your_local_repository_root>/scripts
  $ export K3S_HOST=<Copied FQDN of K3s host>
  $ export KUBECONFIG_DIR=<Full path to default kubeconfig directory>
  ```

  Typical`KUBECONFIG_DIR` values include `/c/Users/<username>/.kube` or `/mnt/c/Users/<username>/.kube` for a WSL based environment.  For native Linux the default location is `~/.kube`.  Make sure that the path chosen reflects your client configuration.

- **Note:**  Before downloading the kubeconfig it is strongly recommended to save a copy of the existing kubeconfig file.
- To download the kubeconfig, run
  ```
  $ ./download_kubeconfig.sh
  ```
- Leave the bash session running since you will use it when configuring Argo CD

The download script will query the K3s host VM for the kubeconfig file.  As soon as the file has been created it will be downloaded automatically by the script.  The script will also download the AKS cluster kubeconfig.
  
Verify cluster access:
```
kubectl config get-contexts -o name
kubectl config use-context default
kubectl get nodes
kubectl config use-context demo-aks
kubectl get nodes
```

**Note:**  `download_kubeconfig.sh` will make a backup of the original kubeconfig file (`config<random>.bak`) and then overwrite the existing default kubeconfig file.  To restore the original `config` file, simply run `mv ${KUBECONFIG_DIR}/config<random>.bak  ${KUBECONFIG_DIR}/config` or use the manually copied safety backup.

**Note:**  `download_kubeconfig.sh` uses the `scp` option `StrictHostKeyChecking no`.  This is not recommended practice, but is used in this demo environment to suppress manual host confirmation to simplify download automation of kubeconfig.

**Note:**  Setting the environment variables is only needed once per bash session.  As long as the K3s resource group ID remains the same, the FQDN will not change.  This remark applies even to the case where the resource groups are deleted completely.
