#/bin/bash
set -euo pipefail

# Login information for Azure VM hosting ArgoCD service.
SERVER=demo-37yjin46oafey.westeurope.cloudapp.azure.com
USERNAME=adminuser

# Download kubeconfig file from VM.
scp -o "StrictHostKeyChecking no" ${USERNAME}@${SERVER}:k3s-config .

# Download node token from VM.
scp -o "StrictHostKeyChecking no" ${USERNAME}@${SERVER}:node-token .

# Retrieve random password generated during Argo CD installation.
ARGOCD_PWD=$(kubectl --kubeconfig ./k3s-config -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo ${ARGOCD_PWD}  #Kg1Y6SHqPSZlGaVZ

# WSL fix. Must move the new kubeconfig to default WSL location.
mv /c/Users/pelleo/.kube/config /c/Users/pelleo/.kube/config.bak 
cp k3s-config /c/Users/pelleo/.kube/config
export ARGOCD_OPTS='--port-forward-namespace argocd'
argocd login ${SERVER} --password ${ARGOCD_PWD} --username admin

# Reset password.  Ignore error msg "FATA[0030] rpc error: code = Unauthenticated desc = Invalid username or password".
argocd account update-password  --current-password ${ARGOCD_PWD}

# Restore config file
mv /c/Users/pelleo/.kube/config.bak /c/Users/pelleo/.kube/config

# Configure port forwarding.
kubectl --kubeconfig ./k3s-config port-forward service/demo-argo-cd-argocd-server -n argocd 8080:443 

# Open a browser and navigate to http://localhost:8080 and logon on using the new password:
# Username: admin
# Password: <new password>
