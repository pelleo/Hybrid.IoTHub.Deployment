#/bin/bash
# Ignore non-zero exit from argocd account update-password.
set +e

# Login information for Azure VM hosting Argo CD service.
server=${K3S_HOST}

# Repository information.
repo_url=${HYBRID_IOTHUB_REPO_URL}
[[ -z ${repo_url} ]] && repo_url=${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}
repo_name=${repo_url##*/}
repo_name=${repo_name%%.git}

# Argo CD config.
argocd_namespace=argocd
argocd_admin=admin
argocd_pwd=${ARGOCD_PWD}
argocd_app_path=clusters/k3s/guestbook

# K3s kubeconfig context required when configuring ArgoCD.
echo K8s contexts:
kubectl config get-contexts -o name
kubectl config use-context default

# Monitor Argo CD deploymemnt.  Timeout after 10 minutes.
n=30
for (( i=1; i<=n; i++ ))
do  
    echo 
    echo Checking Argo CD container status ${i} times out of ${n} ...
    echo 
    sleep 20
    
    # Test if there are containers still not ready
    ready_status=$(kubectl -n ${argocd_namespace} get pods -o jsonpath='{.items[*].status.containerStatuses[?(@.ready==false)].ready}' )

    # Get container status objects, convert to array of objects (jq -s .)
    container_status=$(kubectl -n ${argocd_namespace} get pods -o jsonpath='{.items[*].status.containerStatuses[]}' | jq -s .)
    echo ${container_status} | jq -r  '["READY", "CONTAINER NAME"], ["-----", "----------------------"], (.[] | [.ready, .name]) | @tsv'

    # Exit loop if all containers are ready ("control statement form").
    [[ ! -z ${ready_status} ]] || break
done

# Give some extra time for everything to stabilize.
sleep 10
echo 
echo Resources in ${argocd_namespace} namespace:
echo 
kubectl -n ${argocd_namespace} get all

# Retrieve random password generated during ArgoCD installation.
echo 
echo Initial Argo CD password:
argocd_auto_pwd=$(kubectl -n ${argocd_namespace} get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo ${argocd_auto_pwd}

# Reset password.  Ignore error msg "FATA[0030] rpc error: code = Unauthenticated desc = Invalid username or password".
export ARGOCD_OPTS='--port-forward-namespace argocd'

echo
echo User context:
whoami

echo 
echo ${HOME}/.kube:
ls -al ${HOME}/.kube
argocd login ${server} --password ${argocd_auto_pwd} --username ${argocd_admin} --insecure

# Install sample application.  New login required since credentials changed.
#argocd login ${server} --password ${argocd_pwd}  --username ${argocd_admin} --insecure

echo 
echo Creating guestbook sample app ...
echo 
sleep 5
argocd app create guestbook --repo ${repo_url} --path ${argocd_app_path} --dest-server https://kubernetes.default.svc --dest-namespace default

# Connect GitHub repo.
echo 
echo Connecting GitHub repo ${repo_url} ...
echo 
argocd repo add ${repo_url}

# Add AKS cluster to ArgoCD
echo 
echo Adding AKS cluster ...
echo 
argocd cluster add demo-aks

# Allow direct external access (no port-forwarding required).  MUST INSTALL LOADBALANCER RESOURCE!!!  NodePort will not work in Azure!!!
#kubectl patch svc/${ARGOCD_SERVER_SVC_NAME} -n ${ARGOCD_NAMESPACE} -p '{"spec": {"type": "LoadBalancer"}}'

echo 
echo Changing Argo CD password ...
echo 
sleep 5
argocd account update-password --current-password ${argocd_auto_pwd} --new-password ${argocd_pwd} --insecure
