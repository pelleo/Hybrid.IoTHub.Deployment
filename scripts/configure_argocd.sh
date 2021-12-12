#/bin/bash
set -euo pipefail

# Login information for Azure VM hosting Argo CD service.
SERVER=demo-y4sz7dkvnweq4.westeurope.cloudapp.azure.com
ADMIN_USERNAME=adminuser

# Default local kubeconfig directory.
KUBECONFIG_DIR=/c/Users/pelleo/.kube

# AKS cluster info.
AKS_RG_NAME=rg-aks-demo
AKS_CLUSTER_NAME=demo-aks

# Argo CD config.
ARGOCD_NAMESPACE=argocd
ARGOCD_ADMIN=admin
ARGOCD_PWD=P@szw0rd
ARGOCD_APP_PATH=clusters/k3s/guestbook

# Repository information.
REPO_URL=https://github.com/pelleo/Hybrid.IoTHub.Deployment.git
REPO_NAME=${REPO_URL##*/}
REPO_NAME=${REPO_NAME%%.git}

# Get path to current script. Use below syntax rather than SCRIPTPATH=`pwd` 
# for proper handling of edge cases like spaces and symbolic links.
SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
LOCAL_PARENT_DIR=${SCRIPT_PATH%%${REPO_NAME}*}
LOCAL_REPO_ROOT=${LOCAL_PARENT_DIR}/${REPO_NAME}

# Navigate to script dir.  Download kubeconfig and node token from VM.
ssh-keygen -f ${HOME}/.ssh/known_hosts -R ${SERVER}
scp -o "StrictHostKeyChecking no" ${ADMIN_USERNAME}@${SERVER}:k3s-config ${LOCAL_REPO_ROOT}/local
scp -o "StrictHostKeyChecking no" ${ADMIN_USERNAME}@${SERVER}:node-token ${LOCAL_REPO_ROOT}/local

# WSL fix. Must copy the new kubeconfig to default WSL location.
mv ${KUBECONFIG_DIR}/config ${KUBECONFIG_DIR}/config.bak           # Backup existing kubeconfig
cp ${LOCAL_REPO_ROOT}/local/k3s-config ${KUBECONFIG_DIR}/config

# Merge AKS cluster kubeconfig into default config store.
az aks get-credentials -g ${AKS_RG_NAME} -n ${AKS_CLUSTER_NAME}

# K3s kubeconfig context required when configuring ArgoCD.
kubectl config get-contexts -o name
kubectl config use-context default

# Verify ArgoCD deploymemnt.  Timeout after 10 minutes.
kubectl -n ${ARGOCD_NAMESPACE} get all
ARGOCD_SERVER_POD_NAME=$(kubectl get pod -n ${ARGOCD_NAMESPACE} -l app.kubernetes.io/name=argocd-server --output=jsonpath="{.items[*].metadata.name}")
ARGOCD_SERVER_SVC_NAME=$(kubectl get svc -n ${ARGOCD_NAMESPACE} -l app.kubernetes.io/name=argocd-server --output=jsonpath="{.items[*].metadata.name}")
kubectl wait --for=condition=Ready --timeout=600s -n ${ARGOCD_NAMESPACE} pod/${ARGOCD_SERVER_POD_NAME}
sleep 10s

# Retrieve random password generated during ArgoCD installation.
ARGOCD_AUTO_PWD=$(kubectl -n ${ARGOCD_NAMESPACE} get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo ${ARGOCD_AUTO_PWD}

# Reset password.  Ignore error msg "FATA[0030] rpc error: code = Unauthenticated desc = Invalid username or password".
export ARGOCD_OPTS='--port-forward-namespace argocd'
argocd login ${SERVER} --password ${ARGOCD_AUTO_PWD} --username ${ARGOCD_ADMIN} --insecure
argocd account update-password --current-password ${ARGOCD_AUTO_PWD} --new-password ${ARGOCD_PWD} --insecure

# Allow direct external access (no port-forwarding required).  MUST INSTALL LOADBALANCER RESOURCE!!!  NodePort will not work in Azure!!!
#kubectl expose deployment.apps/demo-argo-cd-argocd-server --type="NodePort" --port 8080 --name=argo-nodeport -n argocd  
#kubectl patch service/demo-argo-cd-argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'
#kubectl patch svc/${ARGOCD_SERVER_SVC_NAME} -n ${ARGOCD_NAMESPACE} -p '{"spec": {"type": "LoadBalancer"}}'

# Install sample application.  New login required since credentials changed.
argocd login ${SERVER} --password ${ARGOCD_PWD}  --username ${ARGOCD_ADMIN} --insecure
argocd app create guestbook --repo ${REPO_URL} --path ${ARGOCD_APP_PATH} --dest-server https://kubernetes.default.svc --dest-namespace default

# Connect GitHub repo.
argocd repo add ${REPO_URL}

# Add AKS cluster to ArgoCD
kubectl config get-contexts -o name
argocd cluster add demo-aks

# Configure port forwarding.
kubectl port-forward svc/${ARGOCD_SERVER_SVC_NAME} -n ${ARGOCD_NAMESPACE} 8080:443 

# Open a browser and navigate to http://localhost:8080 and logon on using the new password:
#
# Username: admin
# Password: <new password>
#
# When done, type ctrl-C to terminate port-forwarding.

# Restore config file.
mv ${KUBECONFIG_DIR}/config.bak ${KUBECONFIG_DIR}/config
