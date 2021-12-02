#/bin/bash
set -euo pipefail

# Login information for Azure VM hosting ArgoCD service.
SERVER=demo-37yjin46oafey.westeurope.cloudapp.azure.com
ADMIN_USERNAME=adminuser

# .kube parent directory.  This is usually the user home directory.
HOME_DIR=/c/Users/pelleo

# Download kubeconfig and node token from VM.
scp -o "StrictHostKeyChecking no" ${ADMIN_USERNAME}@${SERVER}:k3s-config ../config
scp -o "StrictHostKeyChecking no" ${ADMIN_USERNAME}@${SERVER}:node-token ../config

# Verify deploymemnt of ArgoCD.
kubectl --kubeconfig ../config/k3s-config -n argocd get all

# Retrieve random password generated during ArgoCD installation.
ARGOCD_PWD=$(kubectl --kubeconfig ../config/k3s-config -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo ${ARGOCD_PWD}

# WSL fix. Must move the new kubeconfig to default WSL location.
mv ${HOME_DIR}/.kube/config ${HOME_DIR}/.kube/config.bak 
cp ../config/k3s-config ${HOME_DIR}/.kube/config
export ARGOCD_OPTS='--port-forward-namespace argocd'
argocd login ${SERVER} --password ${ARGOCD_PWD} --username admin

# Reset password.  Ignore error msg "FATA[0030] rpc error: code = Unauthenticated desc = Invalid username or password".
argocd account update-password  --current-password ${ARGOCD_PWD}

# Restore config file.
mv ${HOME_DIR}/.kube/config.bak ${HOME_DIR}/.kube/config

# Configure port forwarding.
kubectl --kubeconfig ../config/k3s-config port-forward service/demo-argo-cd-argocd-server -n argocd 8080:443 

# Open a browser and navigate to http://localhost:8080 and logon on using the new password:
# Username: admin
# Password: <new password>
