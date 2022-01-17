# Introduction
This demo sample is based on the experinces from implementing an IoT Hub dev/test environment for a real customer.  The purpose of the demo is to provide a sample that can be installed with a minimum of configuration input.  The current implementation does not allow maximum flexibility in terms of allowing the end user to spin up IoT environments to test different configurations.  

# Repository structure
The repository consists of four major components:
1.  `.github/workflows`.  This is the default location for Git Actions yaml code.  It consists of a single workflow file, `main.yml`.  The workflow consists of two jobs ("stages" in DevOps pipeline speak): `Deploy` and `Configure`.  The first job runs the `create_infra.sh` in the `scripts` folder, which creates all Azure resources.  The second job finishes the configuration of the K3s cluster by downloading and exposing the kubeconfig as an artifact.  It also completes the Argo CD setup.
2. `clusters`.  This is where Kubernetes manifests to be deployed as Argo CD applications should be stored.  There is one subfolder for apps to be run in the K3s and another folder for AKS apps.  Feel free to create additional Argod CD applications
3. `deployment/bicep`.  Home to all bicep templates responsible for creating the Azure resources, see the bicep [documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/overview) for information on how the resoures get created
4. `scripts`.  Bash scripts that execute the bicep templates, create SSH keys and manages K8s and Argo CD configuration

# Cloud-init
[Cloud-init](https://cloudinit.readthedocs.io/en/latest/) is a cross-platform tool for first-time boot VM initialization.  It supports all major Linux distributions across a wide range of public cloud providers.  It also supports private clouds and bare-metal installations.

We have leveraged cloud-init together with bicep [deployment scripts](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/deployment-script-bicep) to demonstrate how the K3s host can be configured in an automated fashion.

The gist of cloud-init is the [cloud-config](https://cloudinit.readthedocs.io/en/latest/topics/examples.html).  The configuration is encoded using YAML syntax.  The first line in a cloud config file must be `#cloud-config` (no space after the hash symbol).  In this sample we create the cloud config dynamically via a [script](/deployment/bicep/modules/create_cloud_init_input_string_bicep).  The cloud config is stored as a base64 encoded string that is subsequently fed into a bicep [deployment script resource](../deployment/bicep/modules/vm-infra.bicep) (search for `generateCloudInitDeploymentScript`), which creates the cloud config and returns it as input to the `customData` of the virtual machine resource.  Here is how it works:

1.  Bicep runs the `generateCloudInitDeploymentScript` resource, which has a URI that points to the cloud-init script.  The script takes a number of input variables stored as environment variables.  In particular, note the external FQDN of the virtual machine, which isn't known until after the external IP resource has been created
2.  The script builds the cloud config YAML dynamically using the expanded environment variables and stores the result in a base64 encoded string.  The deployment script is executed in an Azure container instance, which is managed transparently to the user
3.  The string is piped via `awk` into a JSON object that consists of a single key/value pair, which is temporarily stored in the location pointed to by the built-in variable `AZ_SCRIPTS_OUTPUT_PATH` that maps to the storage account specified in the `storageAccountSettings` element of the bicep deployment script resource
4.  Bicep references the resulting cloud config string as `generateCloudInitDeploymentScript.properties.outputs.cloudInitFileAsBase64`, which can now be used by the virtual machine template, thus providing the custom data.  In fact, `cloudInitFileAsBase64` is the key in the aforementioned JSON object.

# Waiting for kubernetes resources
When deploying K8s resources, it is sometimes necessary to wait for certain pods to become fully operational before subsequent configuration steps can proceed.  Unfortunately, the `kubectl wait` command doesn't always work as expected.  To address this problem we have devised a pattern that checks the status of each container in a given pod by plumming the jsonpath of the corresponding K8s object.  This method has turned out to very reliable in terms of ensuring that a pod is fully operational before continuing.  This pattern is applied to the pods that make up the Argo CD service, see [here](../scripts/configure_argocd.sh) for details.
