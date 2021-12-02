#/bin/bash
set -euo pipefail

# Login information for Azure VM hosting ArgoCD service.
SERVER=demo-37yjin46oafey.westeurope.cloudapp.azure.com
ADMIN_USERNAME=adminuser

# Bash local home directory.
HOME_DIR=/home/pelleo

# Default local kubeconfig directory.
KUBECONFIG_DIR=/c/Users/pelleo/.kube

# K3s local config directory.
K3S_CONFIG_DIR=../config

# Download kubeconfig and node token from VM.
ssh-keygen -f ${HOME_DIR}/.ssh/known_hosts -R ${SERVER}
scp -o "StrictHostKeyChecking no" ${ADMIN_USERNAME}@${SERVER}:k3s-config ${K3S_CONFIG_DIR}
scp -o "StrictHostKeyChecking no" ${ADMIN_USERNAME}@${SERVER}:node-token ${K3S_CONFIG_DIR}

# Verify deploymemnt of ArgoCD.
kubectl --kubeconfig ${K3S_CONFIG_DIR}/k3s-config -n argocd get all

# Retrieve random password generated during ArgoCD installation.
ARGOCD_PWD=$(kubectl --kubeconfig ${K3S_CONFIG_DIR}//k3s-config -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo ${ARGOCD_PWD}

# WSL fix. Must move the new kubeconfig to default WSL location.
mv ${KUBECONFIG_DIR}/config ${KUBECONFIG_DIR}/config.bak 
cp ${K3S_CONFIG_DIR}/k3s-config ${KUBECONFIG_DIR}/config

# Reset password.  Ignore error msg "FATA[0030] rpc error: code = Unauthenticated desc = Invalid username or password".
export ARGOCD_OPTS='--port-forward-namespace argocd'
argocd login ${SERVER} --password ${ARGOCD_PWD} --username admin
argocd account update-password  --current-password ${ARGOCD_PWD}

# Restore config file.
mv ${KUBECONFIG_DIR}/config.bak ${KUBECONFIG_DIR}/config

# Configure port forwarding.
kubectl --kubeconfig ${K3S_CONFIG_DIR}/k3s-config port-forward service/demo-argo-cd-argocd-server -n argocd 8080:443 

# Open a browser and navigate to http://localhost:8080 and logon on using the new password:
# Username: admin
# Password: <new password>
