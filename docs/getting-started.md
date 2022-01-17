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
ACCOUNT=$(az account list --query "[?isDefault]")
echo ${ACCOUNT} | jq

# Change subscription if necessary.
az account set -s <your subscription name>

# Save subscription ID and tenant ID for future reference.
ACCOUNT=$(az account list --query "[?isDefault]")
SUBSCRIPTION_ID=$(echo ${ACCOUNT} | jq -r '.[].id')
TENANT_ID=$(echo ${ACCOUNT} | jq -r '.[].tenantId')
echo ${SUBSCRIPTION_ID}
echo ${TENANT_ID}
```

## Get the code
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
# Your GitHub username will be used by the deployment scripts.
export GIT_HUB_USERNAME=<your GitHub username>

# Navigate to home directory.
cd

# Create a directory in which you want to create local copy of your forked repo.
mkdir -p repos
cd repos
git clone https://github.com/${GIT_HUB_USERNAME}/Hybrid.IoTHub.Deployment.git
```
Substitute `<your_username>` with your actual GitHub username.  When prompted, enter your GitHub username.  For password, use your recently created personal access token.

## Create Service Principal
In order for the pipeline and the AKS cluster to function properly it is necessary to create a service principal.  This service principal (SP) will serve as a "catch all" whenever there is a need for a service principal.  It will be granted owner/contributor rights at the subscription level.  *It is strongly advised not to create this service principal in a subscription that is used for production purposes*.  Note the `--sdk-auth` switch in the SP creation command.  It is used to output the SP credentials in format that is needed when setting up Git Actions.
```
# Create service principal for Azure authentication (output is compatible with Azure SDK auth file).
AZURE_CREDENTIALS=$(az ad sp create-for-rbac --role Contributor --sdk-auth)

# Save entire JSON output as it will be required when setting up Git Actions.
echo ${AZURE_CREDENTIALS} | jq

# Save client ID and client secret.  This will be used when assigning an SP to the AKS service.
export AKS_CLIENT_ID=$(echo ${AZURE_CREDENTIALS} | jq -r '.clientId')
export AKS_CLIENT_SECRET=$(echo ${AZURE_CREDENTIALS} | jq -r '.clientSecret')

echo ${AKS_CLIENT_ID}
echo ${AKS_CLIENT_SECRET}
```
**Note:** Do not close this terminal window, since the environment variables will be needed when creating the environment via local script execution, or when configuring GitHub secrets that are needed for remote script execution.

## Create SSH key pair
We will generate an SSH key pair specifically for logging in to the AKS and K3s host VMs in Azure via SSH.  This key pair will be used to create the environment when executing the scripts locally as well as remotely via Git actions.

Navigate to the `scripts` directory.  Run
```
./create_ssh_key_pair.sh
```
This will create a private and a public key in the `./local/.ssh` directory.  There is also a third file, `id_rsa_github_secret`, which contains the private key formatted in way that is suitable for storing the key as a GitHub secret.

**Note:**  The `local` folder and its subfolders are not uploaded to GitHub.  This folder will be used to hold output data from the scripts that is not meant to be version controlled.

## Create configuration parameters for the demo application
Provide values for the environment variables below.  The actual values do not matter as long as they make sense in your execution environment.
```
# Provide name of Azure region in  which to deploy resources, e.g., westeurope.
export LOCATION=<your Azure region>

# Provide name of AKS cluster resource group to be created, e.g., rg-aks-demo.
export AKS_RG_NAME=<your aks cluster resource group>

# Provide name of K3s cluster resource group to be created, e.g., rg-k3s-demo.
export K3S_RG_NAME=<your K3s cluster resource group>

# Provide public SSH key.  Needed by bicep when creating AKS and K3s hosts.
export SSH_RSA_PUBLIC_KEY=$(cat ./local/.ssh/id_rsa.pub)

# Provide path to your default local kubeconfig directory.  On Linux based 
# systems this would be something like `${HOME}/.kube`.  Some WSL systems
# use `/c/Users/<username>/.kube` or `/mnt/c/Users/<username>/.kube`.  The 
# actual setting will depend on your client workstation configuration.
export KUBECONFIG_DIR=<your kubeconfig path>

# Provide a password for Argo CD login, e.g., P@szw0rd.
export ARGOCD_PWD=<your Argo CD password>
```
The above environment variables will be used by the setup scripts when executed locally.  In addition, they will also be used when creating the GitHub secrets that are required for remote execution.

# Local script execution
The code snippet below describes how to create the demo environment by executing the scripts in the `./scripts` directory locally.
```
# Create the Azure infrastructure:
./scripts/create_infra.sh

# The command will take approximately 5-6 minutes to complete.  Bicep output 
# will be written to `./local/deployment-output.txt`. 

# Set environment variable for K3s host, which is used by donwload script.
export K3S_HOST=$(cat ./local/deployment-output.txt | jq -r '.fqdn.value')
echo ${K3S_HOST}

# Download kubeconfig and store at default location.  Old config will be
# automatically backed up as configNNNN, where NNNN is a four-digit random number.
./scripts/download_kubeconfig.sh
chmod 600 ${KUBECONFIG_DIR}/config

# Configure Argo CD on K3s cluster.
./scripts/configure_argocd.sh
```
You may optionally want to verify the cluster status:
```
# Get cluster contexts.
kubectl config get-contexts -o name

# Verify AKS cluster.
kubectl cluster-info

# Verify K3s cluster.
kubectl config use-context default
kubectl cluster-info
```
**Note:**  `download_kubeconfig.sh` will make a backup of the original kubeconfig file (`config<random>.bak`) and then overwrite the existing default kubeconfig file.  To restore the original `config` file, simply run `mv ${KUBECONFIG_DIR}/config<random>.bak  ${KUBECONFIG_DIR}/config` or use the manually copied safety backup.

**Note:**  `download_kubeconfig.sh` uses the `scp` option `StrictHostKeyChecking no`.  This is not recommended practice, but is used in this demo environment to suppress manual host confirmation to simplify download automation of kubeconfig.

## Log on to Argo CD
By default, Argo CD is not configured for external access, which would require an external load balancer (this is not part of the current distribution).  Before accessing the Argo CD web UI you need to configure port-forwarding:
```
kubectl port-forward -n argocd svc/argocd-demo-server 8080:80
```
Open a web browser and enter the URL `http://localhost:8080`.  Ignore the safety warnings and enter the Argo CD credentials (`admin` and `<your Argo CD password>`).

## Run the Argo CD demo application
There should be a preconfigured `guestbook` application in the Argo CD web UI.  Click `SYNC` to initiate the deployment of the `guestbook` test application located in `./clusters/k3s/guestbook`.  After a few second you should see the resources up and running in the  `default` namespace of the K3s cluster (remember to choose the `default` cluster context when using `kubectl`).

## Add an Argo CD demo application
On the Argo CD GUI main page:
- Click `+ NEW APP`
- Fill in the following information:
  - Application Name:  An arbitry name for your application, e.g., `guestbookaks`
  - Project: `default`
  - SYNC POLICY: `Manual`
  - SYNC OPTIONS: Check `AUTO-CREATE NAMESPACE`
  - Repository URL: Select your repository from the dropdown list
  - Revision: `HEAD`
  - Path: `clusters/aks/guestbook`
  - Cluster Name:  Switch from `URL` to `NAME` and select the AKS cluster name from the dropdown list
  - Namespace: `guestbook`
- Click `CREATE`

Select the new application and synchronize manually.  After a few moments the guestbook application should be up and running in the AKS cluster.  To verify this via `kubectl`:
```
kubectl config use-context demo-aks
kubectl get all -n guestbook
```
# Remote script execution via Git Actions
In this section we will demonstrate a different deployment approach.  Instead of running the scripts locally they will be executed remotely by Git Actions.  As long as all the steps in the setup sections have been carried out, these two alternatives are completely independent.

## Create GitHub secrets
If not already logged in to GitHub, do so now and navigate to the recently forked repository.  The following GitHub secrets must be created:
- `AZURE_CREDENTIALS`
- `AKS_CLIENT_ID`
- `AKS_CLIENT_SECRET`
- `SSH_RSA_PUBLIC_KEY` 
- `SSH_RSA_PRIVATE_KEY`
- `LOCATION`
- `AKS_RG_NAME`
- `K3S_RG_NAME`

Before creating the GitHub secrets, make sure that you have the requisite information available by copying the output of the following commands:
```
# Get value for AZURE_CREDENTIALS. Be sure to collect entire JSON object.
echo ${AZURE_CREDENTIALS} | jq

# Get value for AKS_CLIENT_ID
echo ${AKS_CLIENT_ID}

# Get value for AKS_CLIENT_SECRET
echo ${AKS_CLIENT_SECRET}
```

The value of `SSH_RSA_PUBLIC_KEY` is available in `<your_local_repository_root>/local/.ssh/id_rsa.pub`.  If you created the `repos` folder in your bash home directory you can obtain the value as
```
echo \'$(cat ~/repos/Hybrid.IoTHub.Deployment/local/.ssh/id_rsa.pub)\'
```
Similarly, the value of `SSH_RSA_PRIVATE_KEY` is obtained as
```
echo \'$(cat ~/repos/Hybrid.IoTHub.Deployment/local/.ssh/id_rsa_github_secret)\'
```

If you cloned the sample to a different location, make sure to use the proper path for `<your_local_repository_root>`

Finally, copy the values of the bicep configuration variables:
```
echo ${LOCATION}
echo ${AKS_RG_NAME}
echo ${K3S_RG_NAME}
```

To create the secrets, select `Settings` from the horizontal GitHub menu and then `Secrets`.  In turn, create:
- Name: `AZURE_CREDENTIALS`
  - Value: Paste in the saved copy of `${AZURE_CREDENTIALS}`
- Name: `AKS_CLIENT_ID`          
  - Value: Paste in the saved copy of `${AKS_CLIENT_ID}`
- Name: `AKS_CLIENT_SECRET`      
  - Value: Paste in the saved copy of `${AKS_CLIENT_SECRET}`
- Name: `SSH_RSA_PUBLIC_KEY`     
  - Value: Paste in the contents of `<your_local_repository_root>/local/.ssh/id_rsa.pub`   
- Name: `SSH_RSA_PRIVATE_KEY`  
  - Value: Paste in the contents of `<your_local_repository_root>/local/.ssh/id_rsa_github_secret` 
- Name: `LOCATION`
  - Value: Paste in the saved copy of `${LOCATION}`
- Name: `AKS_RG_NAME`
  - Value: Paste in the saved copy of `${AKS_RG_NAME}`
- Name: `K3S_RG_NAME`
  - Value: Paste in the saved copy of `${K3S_RG_NAME}`

Be sure to replace `<your_local_repository_root>` with the proper value.  The URI must point to the cloud-init script file in your repository.

**Note:** DO NOT forget the surrounding single quotes (`'`) when pasting the public SSH key.  Failure to do so will invariably lead to SSH login errors.

**Note**: DO NOT use `id_rsa` when storing the private key as a GitHub secret.  Doing so will cause SSH login to fail.

## Execute GitHub Actions workflow
Select `Actions` from the menu at the top of the page and highlight `IoTHub Infrastructure Deployment` to launch the workflow.  Wait until the workflow terminates.  

For general infromation on Git Actions, please see https://docs.github.com/en/actions

## Download kubeconfig
To access the Argo CD it is necessary to setup port-forwarding, which in turn requires that the kubeconfig be downloaded.  The kubeconfig was automatically downloaded to the proper location in the case when the scripts scripts were executed locally.  In the remote case, however, the kubeconfig is downloaded to the build agents from which Argo CD is subsequently configured.  To download the kubeconfig locally: 
1.  Select the `Summary` link on the Git Actions log page and scroll down to the `Artifacts` section
2.  Select the `kubeconfig` artifact to download the K8s config
3.  Once the download has completed, copy the kubeconfig manually to the proper location, either using the environment variable `KUBECONFIG_DIR` or dragging and dropping via a GUI tool.  **Note:**  Before downloading the kubeconfig it is strongly recommended to save a copy of the existing kubeconfig file.

At this point you should be able to access the K8s clusters via `kubectl`.
```
# Verify K3s cluster.
kubectl config get-contexts -o name
kubectl config use-context default
kubectl cluster-info

# Verify AKS cluster.
kubectl config use-context demo-aks
kubectl cluster-info
```

Finish verification by setting up port-forwarding to Argo CD.
```
kubectl port-forward -n argocd svc/argocd-demo-server 8080:80
```
The Argo CD web UI should now be accessible as described [above](#log-on-to-argo-cd)

**Note:**  Setting the environment variables is only needed once per bash session.  As long as the K3s resource group ID remains the same, the FQDN of the K3s host will not change.  This remark applies even to the case where the resource groups are deleted completely.

# Known issues
The Argo CD login in `configure_argocd.sh` fails randomly with the warning message
```
WARNING: server is not configured with TLS. Proceed (y/n)? 
```
If this happens you can either delete the resource groups completely, wait a while and then rerun Git Actions; or you can retrieve the auto-generated Argo CD password as
```
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```
Next, set up port-forwarding and log on via the Web UI.  You can then add your repository and your AKS cluster using the admin GUI.  Finally, add the `guestbook` sample application following the [above](add-an-argo-cd-demo-application) instructions.

The issue seems to be related to the Argo CLI login request sometimes being redirected to the Argo CD backend service instead of the frontend service, cf. [this](https://github.com/argoproj/argo-cd/issues/611) link.  The long term solution is to set up an external load balancer and patch the Argo CD service properly.
