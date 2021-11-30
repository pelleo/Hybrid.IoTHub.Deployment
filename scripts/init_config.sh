#!/bin/bash

set -euo pipefail


# Install Docker
sudo apt update
sudo apt install apt-transport-https ca-certificates curl software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
sudo apt update
sudo apt install docker-ce -y
sudo systemctl start docker
sudo systemctl enable docker
systemctl status docker

# Add current user to Docker group to avoid having to type sudo 
# every time you are running Docker
sudo usermod -aG docker ${USER}
newgrp docker

# Install K3s Master node
curl -sfL https://get.k3s.io | sh -s - --docker --tls-san 20.123.157.145
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--tls-san x.x.x.x" sh -s -
systemctl status k3s
sudo kubectl get nodes -o wide

# Configure firewall
sudo ufw allow 6443/tcp
sudo ufw allow 443/tcp
systemctl status ufw

# Get token.  Needed if worker nodes are to be joined.
sudo cat /var/lib/rancher/k3s/server/node-token

# Get kube config.  Must be installed on build agents.
sudo ls -al /etc/rancher/k3s
#sudo chmod -R 666 /etc/rancher/k3s/k3s.yaml  # required for kubectl command to work properly
#sudo cat /etc/rancher/k3s/k3s.yaml
sudo cp /etc/rancher/k3s/k3s.yaml ./.kube/config
sudo chown -R adminuser:adminuser ./.kube
#sudo chmod 600 ./.kube/config
ls -al ./.kube

# Download and install Helm
wget https://get.helm.sh/helm-v3.7.1-linux-amd64.tar.gz  
tar -xvf helm-v3.7.1-linux-amd64.tar.gz         # Extract tar file
ls -al ./linux-amd64/                           # List extracted files
sudo mv linux-amd64/helm /usr/local/bin/helm    # Move extracted Helm binary
helm version

# Add standard chart repository to allow for application installation via Helm.
helm repo add stable https://charts.helm.sh/stable
helm repo update

# Install Argo CD
helm repo add argo https://argoproj.github.io/argo-helm
helm upgrade --install demo-argo-cd argo/argo-cd --version 3.26.12
#NAME: demo-argo-cd
#LAST DEPLOYED: Tue Nov 30 11:48:39 2021
#NAMESPACE: default
#STATUS: deployed
#REVISION: 1
#TEST SUITE: None
#NOTES:
#In order to access the server UI you have the following options:
#
#1. kubectl port-forward service/demo-argo-cd-argocd-server -n default 8080:443
#
#    and then open the browser on http://localhost:8080 and accept the certificate
#
#2. enable ingress in the values file `server.ingress.enabled` and either
#      - Add the annotation for ssl passthrough: https://github.com/argoproj/argo-cd/blob/master/docs/operator-manual/ingress.md#option-1-ssl-passthrough
#      - Add the `--insecure` flag to `server.extraArgs` in the values file and terminate SSL at your ingress: https://github.com/argoproj/argo-cd/blob/master/docs/operator-manual/ingress.md#option-2-multiple-ingress-objects-and-hosts
#
#
#After reaching the UI the first time you can login with username: admin and the random password generated during the installation. You can find the password by running:
#
#kubectl -n default get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
#
#(You should delete the initial secret afterwards as suggested by the Getting Started Guide: https://github.com/argoproj/argo-cd/blob/master/docs/getting_started.md#4-login-using-the-cli)

cat << EOF > cloud-init.txt
#cloud-config
package_upgrade: true
packages:
  - curl
output: {all: '| tee -a /var/log/cloud-init-output.log'}
runcmd:
  - curl https://releases.rancher.com/install-docker/18.09.sh | sh
  - sudo usermod -aG docker adminuser
  - curl -sfL https://get.k3s.io | sh -s - server --tls-san demo-37yjin46oafey.westeurope.cloudapp.azure.com
  - sudo ufw allow 6443/tcp
  - sudo ufw allow 443/tcp
  - sudo cp /var/lib/rancher/k3s/server/node-token .
  - sudo chown adminuser:adminuser node-token
  - sudo sed 's/127.0.0.1/demo-37yjin46oafey.westeurope.cloudapp.azure.com/g' /etc/rancher/k3s/k3s.yaml > k3s-config
  - chmod 600 k3s-config
  - wget https://get.helm.sh/helm-v3.7.1-linux-amd64.tar.gz  
  - tar -xvf helm-v3.7.1-linux-amd64.tar.gz 
  - sudo mv linux-amd64/helm /usr/local/bin/helm
  - helm repo add stable https://charts.helm.sh/stable
  - helm repo update
  - helm repo add argo https://argoproj.github.io/argo-helm
  - mkdir -p .kube
  - sudo cp /etc/rancher/k3s/k3s.yaml ./.kube/config
  - sudo chown -R adminuser:adminuser ./.kube
  - sudo kubectl create ns argocd
  - helm upgrade --install demo-argo-cd argo/argo-cd --version 3.26.12 -n argocd
EOF
