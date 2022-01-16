# Hybrid.IoTHub.Deployment
[![IotHub Infrastructure Deployment](https://github.com/pelleo/Hybrid.IoTHub.Deployment/actions/workflows/main.yml/badge.svg?branch=main)](https://github.com/pelleo/Hybrid.IoTHub.Deployment/actions/workflows/main.yml)

This repository contains the necessary code to bring up two K8s environments that can be used to simulate a typical deployment scenario for IoTHub OPC Publisher devtest cycles.  The first environment is used to simulate a "permanent" production cluster:

- Ubuntu Linux virtual machine hosting an "onpremises" K3s cluster that runs [Argo CD](https://argo-cd.readthedocs.io/en/stable/) to support GitOps workflow
- Virtual network representing the corporate network
- Storage account, which can be used to support miscellaneous services such as file shares, etc.
- Azure resource group: `rg-k3s-demo`

All software configuration like installation of the K3s cluster (a single master node), Helm, ArgoCD, etc., is done via [cloud-init](https://cloudinit.readthedocs.io/en/latest/), which makes it possible to apply the same configuration technique - with some minor modifications - across multiple platforms including VMs residing on a corporate LAN or even bare metal installations.

The second environment is an AKS cluster, which is meant to represent an "ephemeral" cloud based devtest environment mimicking the onpremises environment:

- Managed AKS cluster
- IoTHub and optionally also Device Provisioning Service
- File services.  Default: `SMB`
- Azure resource group: `rg-aks-demo`

The Argo CD instance running on the K3s cluster is used to deploy K8s workloads on the AKS as well as the K3s cluster.  Both environments can be created via [GitHub Actions](https://docs.github.com/en/actions) automation or via manual script execution.

# Documentation
Documentation for the Hybrid.IoTHub.Deployment project can be found at:
- [Overview](docs/overview.md)
- [Getting started](docs/getting-started.md)
