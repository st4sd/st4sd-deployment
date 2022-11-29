# Uninstalling ST4SD

Uninstalling ST4SD will:

1. Delete all ST4SD pods in your namespace
2. Delete all secrets ST4SD created (e.g. secrets creating the credentials of the MongoDB instance - this is an unrecoverable step)

Uninstalling ST4SD will not:

1. Delete any of your files in the PersistentVolumeClaim objects you created. You need to manually delete the PVCs
2. Think ill of you, feel free to try ST4SD again!

## Uninstall process

### Requirements

See [requirements](./install-requirements.md) for instructions to install `oc` and `helm`.


1. Use `oc login` to login to your OpenShift cluster
2. Use `oc project <name>` to switch to your namespace
3. Use helm to uninstall the 3 helm releases in your namesapce

    ```bash
    oc project st4sd-stack
    helm uninstall st4sd-namespaced-managed
    # This step deletes the credentials to your ST4SD MongoDB and other Secrets
    helm uninstall st4sd-namespaced-unmanaged
    # This step requires cluster-admin privileges
    helm uninstall st4sd-cluster-scoped
    ```
4. (Optional **and potentially leading to loss of data/functionality**): If there is no other person using ST4SD on the cluster you can also delete the ST4SD `Workflow` crd:

    ```bash
    oc delete crd workflows.st4sd.ibm.com
    ```
    >**Note**: If you are here because you are re-installing ST4SD do not delete the CRD, `scripts/cluster-scoped.sh` will update it if it needs to.
5. (Optional **and potentially leading to loss of data**): Delete the PVCs you created
    >**Note: This step is unrecoverable**
6. (Optional) If you do not plan to return to this namespace ever you can delete it `oc delete project <namespace>`
    >**Note: This step is unrecoverable, it will delete *all* objects in the namespace including PVCs and Secrets**


## I changed my mind, can I reinstall ST4SD?

Absolutely! Just follow our [helm instructions](./install-helm-chart.md).