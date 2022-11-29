# Installation instructions for ST4SD helm-chart

If you run into trouble please check the [troubleshooting guide](troubleshooting.md). If you cannot find a solution to your problem in there please contact us.

## Quick links

- [Prerequisites](#prerequisites)
- [Customize your ST4SD deployment](#customize-your-st4sd-deployment)
- [Overview of the Helm chart](#overview-of-the-helm-chart)
- [Installing from scratch](#installing-from-scratch)
    - [Requirements](#requirements)
    - [Installing](#installing)
- [Updating existing deployments of ST4SD](#updating-existing-deployments-of-st4sd)
    - [Re-using preexisting values](#re-using-preexisting-values)
    - [Updating deployment-options.yaml values](#updating-deployment-optionsyaml-values)
- [Next steps](#next-steps)

## Prerequisites

1. You have cloned this repository
2. You have followed the [requirements instructions](install-requirements.md) and prepared your `deployment-options.yaml` file in the root directory of this git repository clone on your local drive.
3. Your `deployment-options.yaml` file should look like this:
   
    ```yaml
    # Configure persistent storage
    pvcForWorkflowInstances: workflow-instances
    pvcForDatastoreMongoDB: datastore-mongodb
    pvcForRuntimeServiceMetadata: runtime-service

    # Make sure that ${routePrefix}.${clusterRouteDomain} does not exist on your cluster already. Prior to installling your 
    # ST4SD stack, the URL https://${routePrefix}.${clusterRouteDomain} should return an `Application not available` page
    routePrefix: st4sd-prod
    clusterRouteDomain: ${the output of `oc get ingress.config.openshift.io cluster -o jsonpath="{.spec.domain}{'\n'}"`}

    # Configure cluster-scoped objects
    # We suggest that you disable privileged containers and
    # that you use the default values below (OpenShift best practices for SecurityContextConstrainsts).
    allowPrivilegeEscalation: false
    allowPrivilegedContainer: false
    namespaceContainersUidRangeMin: 1000140001
    namespaceContainersUidRangeMax: 1000170000

    # WorkflowContainersUid must be in the range [namespaceContainersUidRangeMin, namespaceContainersUidRangeMax]
    # Pods that mount common PVCs (e.g. pvcForWorkflowInstances)
    # should use the same UID so that they can all read each other's outputs
    workflowContainersUid: 1000140001

    # Runtime configuration
    defaultOrchestratorArguments:
    - --executionMode: development
    - --registerWorkflow: "y"
    ```

## Customize your ST4SD deployment

At this point you can further customize your ST4SD development. You can find the full list of options you can change in the [helm-chart/values.yaml](../helm-chart/values.yaml) file.


## Overview of the Helm chart

Our [helm chart](../helm-chart/) contains 3 ClusterScoped objects, and several namespaced objects (DeploymentConfig, Secret, ConfigMap, Service, Route). We partition these objects into 3 groups:

1. [`st4sd-cluster-scoped`](../scripts/cluster-scoped.sh): involves cluster-scoped objects such as ClusterRoleBinding, SecurityContextConstraints, CustomResourceDefinition. **This is a release that you will very rarely have to modify. It requires elevated Kubernetes permissions and should be installed/upgraded by cluster-admins**.
1. [`st4sd-namespaced-unmanaged`](../scripts/namespaced-unmanaged.sh): Involves namespaced objects such as Secret and ConfigMap. **Even though these objects are namespaced they should not be unecessarilly tampered with directly. In case of misconfigurations, the ST4SD services may behave in unexpected ways**.
1. [`st4sd-namespaced-managed`](../scripts/namespaced-managed.sh): Involves namespaced objects: ConfigMap, DeploymentConfig, Service, Route. **Updates to your ST4SD instance will typically involve changes to these objects and the containers that these objects involve**. 

You are now ready to install your ST4SD stack.

## Installing from scratch

### Requirements

Before proceeding, it is recommended to make sure the requirements are all met.

#### The deployment-options.yaml file is ready and in the correct place

Ensure:

1. You have followed the instructions in [`install-requirements.md`](install-requirements.md)
2. You have put your `deployment-options.yaml` file in the root folder of the cloned git repository on your local disk. 

#### You are in the correct directory

Ensure your current directory is the root folder of this cloned git repository. If this is not the case, `cd` into it.

#### You are logged in to the OpenShift cluster and have the correct permissions

Ensure you are logged in to your OpenShift cluster and you have cluster-admin permissions.

#### You are in the correct OpenShift project

Check with `oc project` that you are in the namespace that you will host your ST4SD deployment.

If you are not, change the project with `oc project $PROJECTNAME`, where `$PROJECTNAME` is the project you want to install ST4SD in.

#### Decide whether to install the production or the development version of ST4SD

By default, the scripts will install the `production` version of ST4SD. If you wish to install the `development` version instead, then before running any of the scripts below run 

```bash
export ST4SD_DEVELOPMENT=yes
```

**NOTE: We recommend installing the `production` version of ST4SD as it is the most stable one**.


### Installing

```bash
# Install `st4sd-cluster-scoped`.
# This is the only step that requires `cluster-admin` privileges.
# The ones that follow only require `admin` privileges in the namespace you are installing ST4SD in.
./scripts/cluster-scoped.sh deployment-options.yaml

# Install `st4sd-namespaced-unmanaged
./scripts/namespaced-unmanaged.sh deployment-options.yaml

# Install `st4sd-namespaced-managed`
./scripts/namespaced-managed.sh deployment-options.yaml
```

You should now see Pods instantiating and pulling images.

> **WARNING**: Do not delete the `st4sd-namespaced-unmanaged` release before you take a snapshot of the mongodb credentials (`oc get -o yaml secret st4sd-datastore-mongodb-credentials`). Otherwise, you may be unable to authenticate to the MongoDB database in the future and therefore will lose access to metadata stored in your ST4SD MongoDB instance.

## Updating existing deployments of ST4SD

### Re-using preexisting values

If you wish to re-use the `deployment-options.yaml` you've used before then run:

```bash
export CUSTOM_HELM_VALUES=no

./scripts/cluster-scoped.sh
./scripts/namespaced-unmanaged.sh
./scripts/namespaced-managed.sh
```

### Updating deployment-options.yaml values

If you want to make changes to your `deployment-options.yaml` then repeat the process in [installing from scratch](#installing-from-scratch):

```bash
export CUSTOM_HELM_VALUES=yes # default value
# prepare deployment-options.yaml
./scripts/cluster-scoped.sh deployment-options.yaml
./scripts/namespaced-unmanaged.sh deployment-options.yaml
./scripts/namespaced-managed.sh deployment-options.yaml
```

**Note**: We will migrate our CI/CD to use the [Operator Lifecycle Framework](https://olm.operatorframework.io/).
In the meantime, you may use the [update_namespace.sh](../scripts/update_namespace.sh) script with a 
[ServiceAccount](../helm-chart/templates/sa-deploy.yaml) to automate the update of `namespaced-managed` objects in your
deployment.

## Next steps

1. Contact us if you would like to automatically receive updates for your `st4sd-namespaced-managed` objects. 
1. Take a look at the [troubleshooting-deployment guide](troubleshooting.md) to ensure that your workflow stack is properly instantiated.
1. [Get started with ST4SD.](https://st4sd.github.io/overview/)
1. Test your ST4SD deployment using the [st4sd-examples notebooks](https://github.com/st4sd/st4sd-examples).
1. Visit the ST4SD runtime service: at `${routePrefix}.{clusterRouteDomain}/rs/`
    >**Note**: Replace `${key}` with the value of `key` in your `deployment-options.yaml` file (the one that you created when following the [requirements instructions](install-requirements.md)).
1. Visit the ST4SD Registry website: at `${routePrefix}.{clusterRouteDomain}/registry-ui/`