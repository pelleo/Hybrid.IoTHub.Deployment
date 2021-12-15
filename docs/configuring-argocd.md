# Prerequisites
Before configuring Argo CD, please be sure to have carried out all necessary steps described in [Getting Started](./getting-started.md).

# Configure Argo CD
Main steps:

- Navigate to the `${REPO_ROOT}/scripts` directory and open `configure_argocd.sh` in a text editor
- Set the following variables:
  ```
  SERVER=<Saved FQDN of K3s host>
  REPO_URL=https://github.com/<your username>/Hybrid.IoTHub.Deployment.git
  ```
  Replace `<your_username>` with your actual GitHub username.  The URL must point to the root of the forked repository.
- Run
  ```
  $ ./configure_argocd.sh
  ```
  The script will periodically check that status of all Argo CD containers to ensure that their status is `Ready` before attempting to configure Argo CD.  Ignore the error message `"FATA[0030] rpc error: code = Unauthenticated desc = Invalid username or password"`.

**Note:**  Editing `configure_argocd.sh` is needed only the first time the GitHub workflow is executed.  As long as the K3s resource group ID remains the same, the FQDN will not change.  This remark applies even to the case where the resource groups are deleted completely.

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
