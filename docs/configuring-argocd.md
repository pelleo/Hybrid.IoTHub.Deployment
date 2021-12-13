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
  $ ./configue_argocd.sh
  ```
  Ignore the error message `"FATA[0030] rpc error: code = Unauthenticated desc = Invalid username or password"`.

**Note:**  Editing `configure_argocd.sh` is needed only the first time the GitHub workflow is executed.  As long as the K3s resource group ID remains the same, the FQDN will not change.  This remark applies even to the case where the resource groups are deleted completely.
