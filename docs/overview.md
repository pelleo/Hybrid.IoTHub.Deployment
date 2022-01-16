# Introduction
This demo sample is based on the experinces from implementing an IoT Hub dev/test environment for a real customer.  The purpose of the demo is to provide a sample that can be installed with a minimum of configuration input.  The current implementation does not allow maximum flexibility in terms of allowing the end user to spin up IoT environments to test different configurations.  

# Repository structure
The repository consists of four major components:
1.  `.github/workflows`.  This is the default location for Git Actions yaml code.  It consists of a single workflow file, `main.yml`.  The workflow consists of two jobs ("stages" in DevOps pipeline speak): `Deploy` and `Configure`.  The first job runs the `create_infra.sh` in the `scripts` folder, which creates all Azure resources.  The second job finishes the configuration of the K3s cluster by downloading and exposing the kubeconfig as an artifact.  It also completes the Argo CD setup.
2. `clusters`.  This is where Kubernetes manifests to be deployed as Argo CD applications should be stored.  There is one subfolder for apps to be run in the K3s and another folder for AKS apps.  Feel free to create additional Argod CD applications
3. `deployment/bicep`.  Home to all bicep templates responsible for creating the Azure resources, see the bicep [documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/overview) for information on how the resoures get created
4. `scripts`.  Bash scripts that execute the bicep templates, create SSH keys and manages K8s and Argo CD configuration

# Cloud-init

# Waiting for kubernetes resources
