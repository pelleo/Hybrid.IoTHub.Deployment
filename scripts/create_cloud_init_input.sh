#/bin/bash
set -euo pipefail

#####################################################################
# 1.  Execute this script manually on the local workstation.  This
#     will generate the cloud-init input file to be used by cloud-init
#     when executing the bicep template via Git Actions
# 2.  Commit and push the local git repo to GitHub
# 3.  Execute the git workflow 'IotHub Infrastructure Deployment'
#####################################################################

# Location of cloud-init input file.
CLOUD_INIT_PATH=../deployment/bicep/modules/cloud-init-k3s-argocd.yml

# The following values must agree with bicep templates.
DNS_LABEL_PREFIX=demo
DNS_PREFIX=${DNS_LABEL_PREFIX}-37yjin46oafey  
LOCATION=westeurope
ADMIN_USERNAME=adminuser
SERVER=${DNS_PREFIX}.${LOCATION}.cloudapp.azure.com

# Use home directory for files to be downloaded from VM.
OUTPUT_DIR=/home/${ADMIN_USERNAME} 

# Generate input file for cloud-init.
cat << EOF > ${CLOUD_INIT_PATH}
#cloud-config
package_upgrade: true
packages:
  - curl
output: {all: '| tee -a /var/log/cloud-init-output.log'}
runcmd:
  - curl https://releases.rancher.com/install-docker/18.09.sh | sh
  - usermod -aG docker ${ADMIN_USERNAME}
  - curl -sfL https://get.k3s.io | sh -s - server --tls-san ${SERVER}
  - ufw allow 6443/tcp
  - ufw allow 443/tcp
  - cp /var/lib/rancher/k3s/server/node-token ${OUTPUT_DIR}/node-token
  - chown ${ADMIN_USERNAME}:${ADMIN_USERNAME} ${OUTPUT_DIR}/node-token
  - sed 's/127.0.0.1/${SERVER}/g' /etc/rancher/k3s/k3s.yaml > ${OUTPUT_DIR}/k3s-config
  - chmod 600 ${OUTPUT_DIR}/k3s-config
  - chown ${ADMIN_USERNAME}:${ADMIN_USERNAME} ${OUTPUT_DIR}/k3s-config
  - wget -c https://get.helm.sh/helm-v3.7.1-linux-amd64.tar.gz -P ${OUTPUT_DIR}
  - tar -xvf ${OUTPUT_DIR}/helm-v3.7.1-linux-amd64.tar.gz --directory ${OUTPUT_DIR}
  - mv ${OUTPUT_DIR}/linux-amd64/helm /usr/local/bin/helm
  - helm repo add stable https://charts.helm.sh/stable
  - helm repo update
  - helm repo add argo https://argoproj.github.io/argo-helm
  - mkdir -p ${OUTPUT_DIR}/.kube
  - cp /etc/rancher/k3s/k3s.yaml ${OUTPUT_DIR}/.kube/config
  - kubectl create ns argocd
  - helm upgrade --kubeconfig /etc/rancher/k3s/k3s.yaml --install demo-argo-cd argo/argo-cd --version 3.26.12 -n argocd
  - rm -rf ${OUTPUT_DIR}/linux-amd64
  - chown -R ${ADMIN_USERNAME}:${ADMIN_USERNAME} ${OUTPUT_DIR}/.kube
  - chown ${ADMIN_USERNAME}:${ADMIN_USERNAME} ${OUTPUT_DIR}/helm-v3.7.1-linux-amd64.tar.gz
  - curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
  - chmod 755 /usr/local/bin/argocd
EOF
