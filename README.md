# Hybrid.IoTHub.Deployment
This repository contains the necessary code to bring up two K8s environments that can be used to simulate a typical deployment scenario for IoTHub OPC publisher workloads.  The first environment is used to simulate a "permamemt" production cluster:

* An Ubuntu Linux virtual machine hosting an "onpremises" K3s cluster that runs an [Argo CD](https://argo-cd.readthedocs.io/en/stable/) instance to support GitOps workflow
* A virtual network representing the corporate network
* A storage account, which can be used to support miscellaneous services such as file shares, etc.
* Azure resource group: `rg-k3s-demo`

All software configuration like installation of the K3s cluster (a single master node), Helm, ArgoCD, etc., is done via [cloud-inti](https://cloudinit.readthedocs.io/en/latest/), which makes it possible to apply the same configuration technique - with some minor modification - across multiple platforms including VMs residing on a corporate LAN or even bare metal installations.

The second environment is an AKS cluster, which is meant to represent an "ephemeral" `devtest` environment mimicking the onpremises environment:

* Managed AKS cluster
* IoTHub and optionally also Device Provisiong Service
* File services.  Default: `SMB`
* Azure resource group: `rg-aks-demo`

The Argo CD instance running on the K3s cluster is used to deploy K8s workloads on both clusters.  Both environments are deployed using [GitHub Actions](https://docs.github.com/en/actions) automation.

# Documentation
Documentation for the Hybrid.IoTHub.Deployment project can be [here](docs/introduction.md)