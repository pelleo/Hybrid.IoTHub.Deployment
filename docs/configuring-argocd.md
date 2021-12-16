# Prerequisites
Before configuring Argo CD, please be sure to have carried out all necessary steps described in [Getting Started](./getting-started.md).

# Configure Argo CD
Carry out the following steps in the same bash terminal that was used to download the kubeconfig:

- Set the following environment variables:
  ```
  export HYBRID_IOTHUB_REPO_URL=https://github.com/<your_username>/Hybrid.IoTHub.Deployment.git
  export ARGOCD_PWD=<your_argocd_password>
  ```
  Replace `<your_username>` with your actual GitHub username.  The URL must point to the root of the forked repository.  Any password will do as long as Argo CD accepts it.  It will be used when loggin on to the Argo CD UI.
- Run
  ```
  $ ./configure_argocd.sh
  ```

The script will periodically check the status of all Argo CD containers to ensure that their status is `Ready` before attempting to configure Argo CD.  Ignore the error message `"FATA[0030] rpc error: code = Unauthenticated desc = Invalid username or password"` and the port-forwarding error message about broken pipes.  

Upon successful termination you should see output similar to
```
<output removed>

Adding AKS cluster ...

INFO[0000] ServiceAccount "argocd-manager" created in namespace "kube-system"
INFO[0000] ClusterRole "argocd-manager-role" created
INFO[0000] ClusterRoleBinding "argocd-manager-role-binding" created
Cluster 'https://demo-ew5f7zh25sedu-75aa13c3.hcp.westeurope.azmk8s.io:443' added
```

**Note:**  Configuring the environment variables is needed only once per bash session. 

# Set up port-forwarding
By default Argo CD does not expose any public endpoints.  Instead the Argo CD main service is accessed via port-forwarding.  It is possible to patch the service to be of LoadBalancer type.  The current implementation does not include a load balancer resource, however.  

Run the following command from your bash terminal:
```
$ kubectl port-forward svc/argocd-demo-server -n argocd 8080:443 
```

Open a browser and navigate to `http://localhost:8080` and logon on using the new password:
- Username: `admin`
- Password: `<new password>`

When done, type `ctrl-C` to terminate port-forwarding.

# Add an application via the Argo CD GUI
Make sure you are logged in to the Argo CD GUI.
- Click `+ NEW APP`
- Fill in the following information:
  - Application Name:  An arbitry name for your application, e.g., `guestbookaks`
  - Project: `default`
  - SYNC POLICY: `Manual`
  - SYNC OPTIONS: Check `AUTO-CREATE NAMESPACE`
  - Repository URL: Select your repository from the dropdown list
  - Revision: `HEAD`
  - Path: `clusters/aks/guestbook`
  - Cluster Name:  Switch from `URL` to `NAME` and select the AKS cluster name from the dropdown list
  - Namespace: `guestbook`
- Click `CREATE`

Select the new application and synchronize manually.  After a few moments the guestbook application should be up and running.
