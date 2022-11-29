# Test your brand new ST4SD workflow stack deployment

Test your ST4SD deployment using the [st4sd-examples notebooks](https://github.ibm.com/st4sd/st4sd-examples).

## Unable to authenticate to the workflow stack microservices

Refer to the [requirements documentation regarding the secure microservices and the associated Role Based Access Control (RBAC) configuration](install-requirements.md#secure-microservices). You may also look at the logs of the `st4sd-authentication-XXX-YYYYY` under the OpenShift namespace that hosts your workflow stack.

## ST4SD Datastore

The very first time that the `st4sd-datastore-mongodb-YY-XXXXX` pod executes, it instantiates a MongoDB database. This step might take a couple of minutes.

 While this step is executing the MongoDB the containers in the `st4sd-datastore-mongodb-YY-XXXXX` and `st4sd-datastore-mongodb-YY-XXXXX` pods will be unable to connect to the MongoDB.

We suggest that you monitor the logs of the container under the `st4sd-datastore-mongodb-YY-XXXXX` pod for a few minutes while it is booting up. At some point you will notice that there are 3 incoming Python Client connections, these are coming from the containers in the `st4sd-datastore-nexus-YY-XXXXXX` and `st4sd-datastore-mongodb-YY-XXXXX` pods. Once you see the log statements, and you can see that all containers of the `centralized-database-nexus-YY-XXXXXX` and `st4sd-datastore-mongodb-YY-XXXXX` pods are in the running state you can start using the centralized-database API.

## ST4SD Runtime Service

Wait for the ST4SD Runtime Service to transition to the `Running` state and then visit it via `https://`
   1. To do that, prefix the `hostRuntimeService` parameter (from the ConfigMap you created in an earlier step) with `https://`
   2. You should be prompted to login to OpenShift. This is to ensure that only people/service-accounts authorized to use the Consumable-Computing RestApi may access it.
   3. Once you login, OpenShift will inform you that the OpenShift oauth-proxy side-car container will be informed that you've successfully logged in. OpenShift will then give you the option to block the OpenShift side-car container from using this information to inform the Consumable-Computing REST-API that you're authorized to use its API. You should click on the positive response that is provided to you (e.g. ensure that check-boxes are filled in, and then click on `Accept/Submit`). You will not have to re-affirm your choices in the future.
   4. That should land you to the Swagger page of the ST4SD Runtime Service.

If your ST4SD Runtime Service pod keeps failing check its stdout it's likely that the `st4sd-runtime-service` ConfigMap is misconfigured. If that is the case, and you do not understand how to fix it by looking at the [`st4sd-runtime-service` documentation](https://github.ibm.com/st4sd/st4sd-runtime-service) please contact us to provide assistance.


## Troubleshooting Helm chart

1. If you do not specify a `clusterRouteDomain` the helm-chart will try to detect the domain of your cluster by running the equivalent of echo `oc get ingress.config.openshift.io cluster -o jsonpath="{.spec.domain}"`. The error below is an indication that either the object does not exist, you do not have adequate Kubernetes privileges to look at it, or it does not have a `spec.domain` field. You need to contact your cluster administrator to provide the `clusterRouteDomain` value.

    ```log
    Error: UPGRADE FAILED: template: workflow-stack/templates/route-consumable-computing.yaml:9:11: executing "helm-chart/templates/route-authentication.yaml" at <include "host.workflowStack" .>: error calling include: template: workflow-stack/templates/_helpers.tpl:19:38: executing "builddomain" at <$route.status.ingress>: can't evaluate field status in type string
    ```


## Miscellaneous

1. If you see pods pending, `oc describe` them to see why they are pending. For example if they are unable to mount the PVCs you created check if you have created them in the namespaced you deployed ST4SD to.
2. If the pods are unable to connect to MongoDB the MongoDB credentials are likely corrupted. You may get here if between re-installs of ST4SD do not clean up the PVC you selected for `pvcForDatastoreMongoDB` and you have deleted the `st4sd-namespaced-managed` helm-release.
3. If after a minute of deploying ST4SD you notice that there are ST4SD microservices pods missing. Run `oc get deploymentconfig -n <the ST4SD namespace>`. If you notice that any DeploymentConfig object has `CURRENT` equal to 0 then this means that the pod associated with that DeploymentConfig may not get scheduled. You can get here if the associated `xxx-deploy` pod failed to start the Pod. To resolve this issue, you can delete the DeploymentConfig object and run the command `CUSTOM_HELM_VALUES=no scripts/namespaced-managed.sh`. This will re-create the DeploymentConfig objects.


## How do I reinstall?

If you cannot troubleshoot your deployment please send us a message first.

Follow the instructions to [uninstall](uninstalling.md) ST4SD and then return here. If you have not used ST4SD at all we recommend deleting the PVCs and creating them from scratch to ensure that there are no leftover files (e.g. in the MongoDB pvc).