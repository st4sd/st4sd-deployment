# Requirements for installing the workflow stack on OpenShift

This guide takes you through the steps required to prepare for installing the ST4SD workflow stack on an OpenShift cluster from scratch.

**Errors here are the primary cause of installation problems so its worth being extra vigilant when executing these steps**. 

As the storage provided can differ from cluster-to-cluster and from IBM Cloud to on-prem it's difficult to automate this step. However it's mainly a case of clicking buttons in the UI for a few minutes.

Once security and storage elements the actual installation is straight-forward.

## Quick Links


- [Requirements](#requirements)
- [Create an OpenShift project to host the stack](#create-an-openshift-project-to-host-the-stack)
- [Create a `deployment-options.yaml` file](#create-a-deployment-optionsyaml-file)
- [Secure MicroServices](#secure-microservices)
- [Storage Setup](#storage-setup)
  - [Using the OpenShift Web UI](#using-the-openshift-web-ui)
- [Determine the domain of your OpenShift cluster](#determine-the-domain-of-your-openshift-cluster-and-decide-the-host-of-the-route-object)
  - [Pick a short, human-readable identifier for your cluster](#pick-a-short-human-readable-identifier-for-your-cluster)
- [Configure SecurityContextConstraints](#configure-securitycontextconstraints)
- [Putting it all together](#putting-it-all-together)
- [Runtime configuration](#runtime-configuration)
  - [Garbage Collection and K8s archiving](#garbage-collection-and-k8s-archiving)

## Requirements

1. **Access to an OpenShift cluster with `cluster-admin` permissions**
    - Required for creation of a kubernetes objects (such as CustomResourceDefinition and Role Based Access Control (RBAC)). Regular updates to the workflow stack do not require `cluster-admin` permissions, only permissions to modify objects in the namespace that holds the workflow stack.
2. **OpenShift command line tools  (`oc` v4.9+)**
    - Instructions: <https://docs.openshift.com/container-platform/4.9/cli_reference/openshift_cli/getting-started-cli.html>
    - Install stable version of`oc` from <https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/>
    - It is good practice to periodically update your `oc` command line utility to ensure that your `oc` binary contains the latest patches and bug-fixes.
3. **This repository cloned onto your laptop**

Some understanding of Kubernetes and OpenShift concepts will be useful, although as long as you have the correct permissions on the OpenShift cluster (`cluster-admin`) following the steps here should work. 

## Create an OpenShift project to host the stack

ST4SD will live in an OpenShift `project`. There can be multiple projects running ST4SD on a given OpenShift cluster, each one with their own set of users, storage, compute-resources etc.

**Create a new project via the CLI**. Here we use the name `st4sd-stack` but you can change this to whatever you like.

```bash
oc new-project st4sd-stack
```

## Create a `deployment-options.yaml` file

Next, open your prefered editor and **create a new file named `deployment-options.yaml`**. You will store a dictionary in this YAML file containing configuration options for your ST4SD deployment. The installation guides ([in-house template](./install-in-house.md) and [helm-chart template](./install-helm-chart.md)) reference the `deployment-options.yaml` file.


## Secure MicroServices

The workflow-stack uses the [OpenShift oauth-proxy side-car container](https://github.com/openshift/oauth-proxy) to secure access to its microservices. 

>**Note: You will be able to login to your MicroServices REST-API services using your OpenShift credentials.**

>**Note: Only people (and ServiceAccounts) that have permissions to list Services inside your OpenShift project/namespace will be able to use your microservices. See [this RoleBinding](../template/RoleBinding/authorize-example.yaml) for the required Role Based Access Control (RBAC) details.**

## Storage Setup

ST4SD needs three `PeristentVolumeClaim` (`PVC`) objects which store your files and the stacks configuration and logs.

**There is guaranteed way to change the capacity of `PersistentVolumeClaim` objects so make sure that you pick the capacity sizes after some careful thought (we've provided some default values below)**. 

**The most critical `PVC` to size is `workflow-instances`. This will hold the workflow output so you need to consider how big the workflows you will run are**. 

We assume kubernetes **dynamic provisioning** is available - this is a feature that means when you ask for some storage of a certain size in kubernetes the system "provisions" it for you from a resource pool (a.k.a. `storage class`) configured by the administrator.

IBM Cloud clusters will have **dynamic provisioning** available

Administrators of on-prem clusters must configure their own dynamic provisioning. In the below instructions we assume an an IBM Cloud environment. You can use any Storage Class that supports mounting the PVC in multiple Pods at the same time (i.e. `ReadWriteMany (RWX)`) in `Filesystem` mode.

### Using the OpenShift Web UI

| Name                       | Min Size | Access       | Storage Class (IBM Cloud) | Purpose                        |
| -------------------------- | -------- | ------------ |---------------------------| ------------------------------ |
| `datastore-mongodb`          | 20GB      | Shared (RWX) | ibmc-file-silver-gid      | Hosts MongoDB                  |
| `runtime-service` | 20GB    | Shared (RWX) | Ibmc-file-bronze-gid | Virtual Experiment metadata |
| `workflow-instances`   | 100GB    | Shared (RWX) | ibmc-file-gold-gid        | Virtual Experiment output                |

>**Note: Make sure you create the PVCs in the same namespace as your ST4SD stack e.g. `sdt4sd-stack`**

For each row in the above table you create a `PVC` by (in OpenShift 4.9 UI)

1. Go to **Storage**-> **PersistentVolumeClaims**
2. Ensure you are in the same project you have created earlier in these instructions (e.g., `st4sd-stack`) by looking at the selected project at top of the page, near the side-bar.
3. Click **Create PersistentVolumeClaim**
4. Set the **Storage Class**  name 
   1. **On IBM Cloud**: Choose the value listed in the **Volume Class** column
   2. **On a On-Prem Cluster**: Choose the name of your **NFS provisioner** e.g. `managed-nfs-storage`
      - If you don't see any storage-class in the drop down then dynamic provisioning may not be set up. Unfortunately, settting it up is outside the scope of this guide.
    >**Note**: It is important that your PVCs can be mounted for read/write access by many pods (RWX).

    >**Note**: It is important that your `workflow-instances` supports `fsgroup` functionality (IBM-Cloud storage-classes with the suffix `-gid` support `fsgroup`).
5. Fill in the other details from the table
   - You **do not need to tick** the _Use label selectors to request storage_ box.

    >**Note:** _You may have to wait some time (usually <10mins, can be almost instantaneous) for the storage to be provisioned. After creating the PVCs wait until their state is *bound* before continuing_
6. Record the PVC names you chose in your `deployment-options.yaml`. If you have used the suggested PVC names above then you may simply insert the text below into your YAML file:
    
    ```yaml
    pvcForWorkflowInstances: workflow-instances
    pvcForDatastoreMongoDB: datastore-mongodb
    pvcForRuntimeServiceMetadata: runtime-service
    ```


## Determine the domain of your OpenShift cluster and decide the host of the Route object

The workflow software stack will listen on a set or URLs (routes). To configure these you need to know the domain of your cluster

If you are using IBM Cloud and an OpenShift 4.x cluster you can find your cluster's domain by using the `oc` command line interface:
```bash
$ oc get ingress.config.openshift.io cluster -o jsonpath="{.spec.domain}{'\n'}"
router-default.st4sd-dal10-b3c-8x32-2z0euc393f34429k4412e5a15d3x4662-0000.us-south.containers.appdomain.cloud
```

>**Note: This step assumes you are logged in with an account that can view Ingress Objects; when in doubt use a `cluster-admin` account.**

Alternatively, you can find out what your cluster's domain is by creating a Service and then exposing it as a Route. OpenShift will create a URL for you in the format `<route-name>.<domain>`.

Make a note of your cluster's `<domain>`, and insert it into your `deployment-options.yaml` file. For example, this is the text you would have to add for the above cluster-route:

```yaml
clusterRouteDomain: st4sd-dal10-b3c-8x32-2z0euc393f34429k4412e5a15d3x4662-0000.us-south.containers.appdomain.cloud
```

Finally, decide a `routePrefix` to prefix your `clusterRouteDomain`. The resulting host `${routePrefix}.${clusterRouteDomain}` will be the URL for your ST4SD microservices ([`st4sd-runtime-service`](https://github.com/st4sd/st4sd-runtime-service) and [`st4sd-datastore`](https://github.com/st4sd/st4sd-datastore)).

Example:

```yaml
routePrefix: st4sd-prod
```

### Pick a short, human-readable identifier for your cluster

The workflow stack supports connecting multiple execution environments to its Centralized Database. Even if you are planning to only ever use 1 execution environment it is still best practice to pick a short and unique name that only contains alphanumerics and hyphens. For example: `challenge-4228-prod`. Update your `deployment-options.yaml` file to include the unique name that you picked. For example:

```yaml
datastoreLabelGateway: challenge-4228-prod
```

## Configure SecurityContextConstraints

We suggest that you disable privileged containers (e.g. root user) running in your namespace because that can lead to security implications down the line. This includes containers running as part of the workflows you execute. 

The ST4SD deployment helm-chart instantiates a `SecurityContextConstraint` which can be configured to place certain constraints to the pods that run in your namespace. We suggest you use the following options:

```yaml
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
```

>**Note**: _If you really want to allow containers running as root and you understand the security implications, then replace `false` above with `true` and `1000140001` with `0`. We suggest that you use the default values above._

## Runtime configuration

You can set the value `defaultOrchestratorArguments` to provide configuration options that apply to all the virtual experiments executed via the [st4sd-runtime-service](https://st4sd.github.io/overview/runtime-service) REST-API.


The format is
```yaml
defaultOrchestratorArguments: 
- $parameter: $value
```

**Note**: Virtual experiments cannot override the command-line arguments you provide in `defaultOrchestratorArguments`.

For example:

```yaml
defaultOrchestratorArguments:
# Always register virtual experiment runs to the ST4SD datastore
- --registerWorkflow: "y"
# Garbage collect and archive Job/Pod objects of SUCCESSFUL tasks after they terminate
# (see section below for more information)
- --executionMode: "development"
```

### Garbage Collection and K8s archiving

You can configure garbage collection by setting a value for the `--executionMode` in the `defaultOrchestratorArguments` filed of your `deployment-options.yaml` file.

All `--executionMode` options:

- `debug`: No garbage collection (default if unset)
- `development`: Garbage collect and archive Job/Pod objects of SUCCESSFUL tasks after they terminate
- `production`: Garbage collection of Job/Pod objects for *ALL*  tasks including those that fail

Archived objects are persisted under `$INSTANCE_DIR/stages/stage<index>/<componentName>` in the `pvcForWorkflowInstances` PVC.


**Note**: See [`elaunch.py`](https://github.com/st4sd/st4sd-runtime-core/blob/master/scripts/elaunch.py) for the full list of the command-line arguments to the ST4SD runtime.

## Registry backend feature gates

The st4sd-registry-backend provides feature gates for administrator to disable or enable functionalities on the st4sd-registry-ui.

### The isGlobalRegistry toggle

If you are planning to expose your st4sd-registry-ui deployment publicly, set the value of `isGlobalRegistry` to `true` . This will disable features such as viewing experiment runs to reduce security concerns.

### Disabling features

Some feature gates are on by default. These settings typically involve giving read-only access to data.

- Set `backendEnableCanvas` to `false` to prevent users from looking at the graph representation of virtual experiments.

### Enabling features

These settings typically involve giving users the ability to create, modify, or run experiments. As such, they are off by default.

- Set `backendEnableBuildCanvas` to `true` to give users the ability to create virtual experiments from scratch through the Registry UI.
- Set `backendEnableEditParameterisation` to `true` to give users the ability to modify the parameterisation of virtual experiments directly from the Registry UI.
- Set `backendEnableRunExperiment` to `true` to give users the ability to run virtual experiments directly from the Registry UI.

## Optional Internal Experiments storage

The st4sd-runtime-service has support for storing DSL 2.0 experiments in its internal storage which is hosted on a S3 bucket.
To enable the Internal Experiments storage create a kubernetes secret in the same namespace as your ST4SD deployment.

Include the following fields:

- S3_ENDPOINT
- S3_BUCKET
- S3_ACCESS_KEY_ID (optional - if s3 bucket is writable by all)
- S3_SECRET_ACCESS_KEY (optional - if s3 bucket is writable by all)
- S3_REGION (optional)

Then set the value `secretNameS3InternalExperiments` to the name of the kubernetes secret.

## Optional Graph Library storage

The st4sd-runtime-service has support for storing re-usable DSL 2.0 graph templates in its Graph Library which is hosted on a S3 bucket.
To enable the Graph Library storage create a kubernetes secret in the same namespace as your ST4SD deployment.

Include the following fields:

- S3_ENDPOINT
- S3_BUCKET
- S3_ACCESS_KEY_ID (optional - if s3 bucket is writable by all)
- S3_SECRET_ACCESS_KEY (optional - if s3 bucket is writable by all)
- S3_REGION (optional)

Then set the value `secretNameS3GraphLibrary` to the name of the kubernetes secret.

## Putting it all together

After you are done following the above instructions, your `deployment-options.yaml` file should look like this:

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
