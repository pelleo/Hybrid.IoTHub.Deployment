#/bin/bash
set -euo pipefail

# Login information for Azure VM hosting ArgoCD service.
SERVER=demo-y4sz7dkvnweq4.westeurope.cloudapp.azure.com
ADMIN_USERNAME=adminuser

# Bash local home directory.
HOME_DIR=/home/pelleo

# Default local kubeconfig directory.
KUBECONFIG_DIR=/c/Users/pelleo/.kube

# K3s local config directory.
K3S_CONFIG_DIR=../config

# ArgoCD credentials.
ARGOCD_ADMIN=admin
NEW_ARGOCD_PWD=P@szw0rd

# Download kubeconfig and node token from VM.
ssh-keygen -f ${HOME_DIR}/.ssh/known_hosts -R ${SERVER}
scp -o "StrictHostKeyChecking no" ${ADMIN_USERNAME}@${SERVER}:k3s-config ${K3S_CONFIG_DIR}
scp -o "StrictHostKeyChecking no" ${ADMIN_USERNAME}@${SERVER}:node-token ${K3S_CONFIG_DIR}

# WSL fix. Must copy the new kubeconfig to default WSL location.
mv ${KUBECONFIG_DIR}/config ${KUBECONFIG_DIR}/config.bak           # Backup existing kubeconfig
cp ${K3S_CONFIG_DIR}/k3s-config ${KUBECONFIG_DIR}/config

# Verify deploymemnt of ArgoCD.
kubectl --kubeconfig ${K3S_CONFIG_DIR}/k3s-config -n argocd get all

# Retrieve random password generated during ArgoCD installation.
ARGOCD_PWD=$(kubectl --kubeconfig ${K3S_CONFIG_DIR}//k3s-config -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo ${ARGOCD_PWD}

# Reset password.  Ignore error msg "FATA[0030] rpc error: code = Unauthenticated desc = Invalid username or password".
export ARGOCD_OPTS='--port-forward-namespace argocd'
argocd login ${SERVER} --password ${ARGOCD_PWD} --username ${ARGOCD_ADMIN} --insecure
argocd account update-password --current-password ${ARGOCD_PWD} --new-password ${NEW_ARGOCD_PWD} --insecure

# Allow direct external access (no port-forwarding required).  MUST INSTALL LOADBALANCER RESOURCE!!!  NodePort will not work in Azure!!!
#kubectl --kubeconfig ${K3S_CONFIG_DIR}/k3s-config expose deployment.apps/demo-argo-cd-argocd-server --type="NodePort" --port 8080 --name=argo-nodeport -n argocd  
#kubectl --kubeconfig ${K3S_CONFIG_DIR}/k3s-config patch service/demo-argo-cd-argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'
kubectl --kubeconfig ${K3S_CONFIG_DIR}/k3s-config patch service/demo-argo-cd-argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Install sample application.
#argocd app create guestbook --repo https://github.com/argoproj/argocd-example-apps.git --path guestbook --dest-server https://kubernetes.default.svc --dest-namespace default
argocd app create guestbook --repo https://github.com/pelleo/Hybrid.IoTHub.Deployment.git --path clusters/k3s/guestbook --dest-server https://kubernetes.default.svc --dest-namespace default

# Optional:  Connect to github repo.
argocd repo add https://github.com/pelleo/Hybrid.IoTHub.Deployment.git

# Add AKS cluster kubeconfig to default config store.
az aks get-credentials -g rg-cloud-demo -n demo-aks

# Add AKS cluster to ArgoCD
argocd cluster add demo-aks

# Restore config file.
mv ${KUBECONFIG_DIR}/config.bak ${KUBECONFIG_DIR}/config

# Configure port forwarding.
kubectl --kubeconfig ${K3S_CONFIG_DIR}/k3s-config port-forward service/demo-argo-cd-argocd-server -n argocd 8080:443 

# Open a browser and navigate to http://localhost:8080 and logon on using the new password:
# Username: admin
# Password: <new password>
