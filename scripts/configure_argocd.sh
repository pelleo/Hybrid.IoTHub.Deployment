#/bin/bash
#set -euo pipefail

# Login information for Azure VM hosting Argo CD service.
SERVER=demo-y4sz7dkvnweq4.westeurope.cloudapp.azure.com
ADMIN_USERNAME=adminuser

# Repository information.
REPO_URL=https://github.com/pelleo/Hybrid.IoTHub.Deployment.git
REPO_NAME=${REPO_URL##*/}
REPO_NAME=${REPO_NAME%%.git}

# Argo CD config.
ARGOCD_NAMESPACE=argocd
ARGOCD_ADMIN=admin
ARGOCD_PWD=P@szw0rd
ARGOCD_APP_PATH=clusters/k3s/guestbook

# Get path to current script. Use below syntax rather than SCRIPTPATH=`pwd` 
# for proper handling of edge cases like spaces and symbolic links.
SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
LOCAL_PARENT_DIR=${SCRIPT_PATH%%${REPO_NAME}*}
LOCAL_REPO_ROOT=${LOCAL_PARENT_DIR}/${REPO_NAME}

# K3s kubeconfig context required when configuring ArgoCD.
kubectl config get-contexts -o name
kubectl config use-context default

# Monitor Argo CD deploymemnt.  Timeout after 10 minutes.
n=50
for (( i=1; i<=n; i++ ))
do  
    echo ""
    echo "Checking container status ${i} times out of ${n}:"
    echo ""
    sleep 10
    
    # Test if there are containers still not ready
    READY_STATUS=$(kubectl -n ${ARGOCD_NAMESPACE} get pods -o jsonpath='{.items[*].status.containerStatuses[?(@.ready==false)].ready}' )

    # Get container status objects, convert to array of objects (jq -s .)
    CONTAINER_STATUS=$(kubectl -n ${ARGOCD_NAMESPACE} get pods -o jsonpath='{.items[*].status.containerStatuses[]}' | jq -s .)
    echo ${CONTAINER_STATUS} | jq -r  '["READY", "CONTAINER NAME"], ["-----", "----------------------"], (.[] | [.ready, .name]) | @tsv'

    # Exit loop if all containers are ready ("control statement form").
    [[ ! -z ${READY_STATUS} ]] || break
done

# Give some extra time for everything to stabilize
sleep 10
echo ""
kubectl -n ${ARGOCD_NAMESPACE} get all
#ARGOCD_SERVER_POD_NAME=$(kubectl get pod -n ${ARGOCD_NAMESPACE} -l app.kubernetes.io/name=argocd-server --output=jsonpath="{.items[*].metadata.name}")
ARGOCD_SERVER_SVC_NAME=$(kubectl get svc -n ${ARGOCD_NAMESPACE} -l app.kubernetes.io/name=argocd-server --output=jsonpath="{.items[*].metadata.name}")
#kubectl wait --for=condition=Ready --timeout=600s -n ${ARGOCD_NAMESPACE} pod/${ARGOCD_SERVER_POD_NAME}

# Retrieve random password generated during ArgoCD installation.
ARGOCD_AUTO_PWD=$(kubectl -n ${ARGOCD_NAMESPACE} get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo ${ARGOCD_AUTO_PWD}

# Reset password.  Ignore error msg "FATA[0030] rpc error: code = Unauthenticated desc = Invalid username or password".
export ARGOCD_OPTS='--port-forward-namespace argocd'
argocd login ${SERVER} --password ${ARGOCD_AUTO_PWD} --username ${ARGOCD_ADMIN} --insecure
argocd account update-password --current-password ${ARGOCD_AUTO_PWD} --new-password ${ARGOCD_PWD} --insecure

# Allow direct external access (no port-forwarding required).  MUST INSTALL LOADBALANCER RESOURCE!!!  NodePort will not work in Azure!!!
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
#kubectl port-forward svc/${ARGOCD_SERVER_SVC_NAME} -n ${ARGOCD_NAMESPACE} 8080:443 

# Open a browser and navigate to http://localhost:8080 and logon on using the new password:
#
# Username: admin
# Password: <new password>
#
# When done, type ctrl-C to terminate port-forwarding.
