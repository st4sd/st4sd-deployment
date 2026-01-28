#!/usr/bin/env sh

# Copyright IBM Inc. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
# Authors:
#  Vassilis Vassiliadis

releaseName="st4sd-local-all"
export ST4SD_DEVELOPMENT=${ST4SD_DEVELOPMENT:-no}
dirScripts=`dirname "${0}"`
dirCurrent=`pwd`

# Defaults are
# DEBUG=no
# ST4SD_DEVELOPMENT=no
# CUSTOM_HELM_VALUES=yes
source ${dirScripts}/deploy-common.sh

if [ "${ST4SD_DEVELOPMENT}" == "yes" ]; then
  st4sd_tag="latest"
  st4sd_use_image_stream_tags="false"
else
  st4sd_tag=${ST4SD_PRODUCTION_TAG:-"bundle-2.0.0-alpha14"}
  st4sd_use_image_stream_tags="true"
fi

st4sd_registry_url="quay.io/st4sd/official-base"

echo_options_for_images_and_pull_secrets >values.yaml

if  [ "$?" != "0" ]; then
  echo "Could not generate values.yaml (exit code $?)"
  cat values.yaml
  exit 1
fi

cat <<EOF >>values.yaml
datastoreLabelGateway: local

pvcForWorkflowInstances: workflow-instances-pvc
pvcForDatastoreMongoDB: datastore-mongodb
pvcForRuntimeServiceMetadata: runtime-service
workflowImagePullSecret: st4sd-base-images
routePrefix: local
clusterRouteDomain: apps-crc.testing

imagesVariant: ":${st4sd_tag}"
useImageStreamTags: ${st4sd_use_image_stream_tags}
installGithubSecretOAuth: false

# Configure cluster-scoped objects
# We suggest that you disable privileged containers and
# that you use the default values below (OpenShift best practices for SecurityContextConstrainsts).
allowPrivilegeEscalation: false
allowPrivilegedContainer: false
namespaceContainersUidRangeMin: 1000140001
namespaceContainersUidRangeMax: 1000170000
namespaceContainersFsGroupRangeMin: 0
namespaceContainersFsGroupRangeMax: 25000
namespaceContainersFsGroupCommon: 0

imagesRuntimeCore: ${st4sd_registry_url}/st4sd-runtime-core
imagesDatastoreMongoDB: ${st4sd_registry_url}/st4sd-datastore-mongodb
imagesRuntimeOperator: ${st4sd_registry_url}/st4sd-runtime-k8s
imagesRuntimeService: ${st4sd_registry_url}/st4sd-runtime-service
imagesDatastore: ${st4sd_registry_url}/st4sd-datastore
imagesRegistryBackend: ${st4sd_registry_url}/st4sd-registry-backend
imagesRegistryUI: ${st4sd_registry_url}/st4sd-registry-ui


# WorkflowContainersUid must be in the range [namespaceContainersUidRangeMin, namespaceContainersUidRangeMax]
# Pods that mount common PVCs (e.g. pvcForWorkflowInstances)
# should use the same UID so that they can all read each other's outputs
workflowContainersUid: 1000140001

defaultOrchestratorArguments: [{"--executionMode": "debug", "--failSafeDelays": "no", "--registerWorkflow": "y"}]


# VV: We trimmed down the resource requirements (e.g. MongoDB suggests using at least 4Gi memory)
# This minimal ST4SD deployment is meant for trying things out - don't use it in production
# Total CPU: 1.58 cores
# Total RAM: 2.7 GB

resources:
  datastoreInstanceReporter:
    limits:
      cpu: 20m
      memory: 256Mi
  datastoreInstanceGateway:
    limits:
      cpu: 150m
      memory: 256Mi
  datastoreNexusDBProxy:
    limits:
      cpu: 250m
      memory: 256Mi
  datastoreNexusRegistry:
    limits:
      cpu: 250m
      memory: 256Mi
  datastoreMongoDB:
    limits:
      cpu: 250m
      memory: 512Mi
  authenticationNginx:
    limits:
      cpu: 50m
      memory: 128Mi
  authenticationProxy:
    limits:
      cpu: 100m
      memory: 128Mi
  runtimeK8s:
    limits:
      cpu: 10m
      memory: 128Mi
  runtimeService:
    limits:
      cpu: 250m
      memory: 256Mi
  registryBackend:
    limits:
      cpu: 250m
      memory: 256Mi
  registryUI:
    limits:
      cpu: 50m
      memory: 256Mi
EOF

cat <<EOF
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: datastore-mongodb
  namespace: st4sd-local
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 4Gi
  volumeMode: Filesystem
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: runtime-service
  namespace: st4sd-local
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 4Gi
  volumeMode: Filesystem
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: workflow-instances-pvc
  namespace: st4sd-local
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 12Gi
  volumeMode: Filesystem
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: default-user-auth
  namespace: st4sd-local
subjects:
  - kind: User
    apiGroup: rbac.authorization.k8s.io
    name: developer
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: st4sd-authenticate-microservices
EOF

helm template --namespace st4sd-local --dry-run --release-name "${releaseName}" ${dirScripts}/../helm-chart/ -f values.yaml

echo "---"
cat ~/projects/st4sd/deployment/helm-chart/crd-workflow.yaml
echo ""

if [ "${st4sd_use_image_stream_tags}" == "true" ]; then
# VV: This will cause DeploymentConfigs to spawn objects for when ST4SD
# uses ImageStreamTags triggers for the DeploymentConfig objects
cat <<EOF
---
kind: ImageStreamImport
apiVersion: image.openshift.io/v1
metadata:
  name: "st4sd-runtime-core"
  namespace: "st4sd-local"
spec:
  import: true
  images:
    - from:
        kind: DockerImage
        name: "${st4sd_registry_url}/st4sd-runtime-core"
      to:
        name: "${st4sd_tag}"
      referencePolicy:
        type: ""
status: {}
---
kind: ImageStreamImport
apiVersion: image.openshift.io/v1
metadata:
  name: "st4sd-runtime-service"
  namespace: "st4sd-local"
spec:
  import: true
  images:
    - from:
        kind: DockerImage
        name: "${st4sd_registry_url}/st4sd-runtime-service"
      to:
        name: "${st4sd_tag}"
      referencePolicy:
        type: ""
status: {}
---
kind: ImageStreamImport
apiVersion: image.openshift.io/v1
metadata:
  name: "st4sd-runtime-k8s"
  namespace: "st4sd-local"
spec:
  import: true
  images:
    - from:
        kind: DockerImage
        name: "${st4sd_registry_url}/st4sd-runtime-k8s"
      to:
        name: "${st4sd_tag}"
      referencePolicy:
        type: ""
status: {}
---
kind: ImageStreamImport
apiVersion: image.openshift.io/v1
metadata:
  name: "st4sd-runtime-k8s-input-s3"
  namespace: "st4sd-local"
spec:
  import: true
  images:
    - from:
        kind: DockerImage
        name: "${st4sd_registry_url}/st4sd-runtime-k8s-input-s3"
      to:
        name: "${st4sd_tag}"
      referencePolicy:
        type: ""
status: {}
---
kind: ImageStreamImport
apiVersion: image.openshift.io/v1
metadata:
  name: "st4sd-runtime-k8s-monitoring"
  namespace: "st4sd-local"
spec:
  import: true
  images:
    - from:
        kind: DockerImage
        name: "${st4sd_registry_url}/st4sd-runtime-k8s-monitoring"
      to:
        name: "${st4sd_tag}"
      referencePolicy:
        type: ""
status: {}
---
kind: ImageStreamImport
apiVersion: image.openshift.io/v1
metadata:
  name: "st4sd-registry-ui"
  namespace: "st4sd-local"
spec:
  import: true
  images:
    - from:
        kind: DockerImage
        name: "${st4sd_registry_url}/st4sd-registry-ui"
      to:
        name: "${st4sd_tag}"
      referencePolicy:
        type: ""
status: {}
---
kind: ImageStreamImport
apiVersion: image.openshift.io/v1
metadata:
  name: "st4sd-registry-backend"
  namespace: "st4sd-local"
spec:
  import: true
  images:
    - from:
        kind: DockerImage
        name: "${st4sd_registry_url}/st4sd-registry-backend"
      to:
        name: "${st4sd_tag}"
      referencePolicy:
        type: ""
status: {}
---
kind: ImageStreamImport
apiVersion: image.openshift.io/v1
metadata:
  name: "st4sd-datastore"
  namespace: "st4sd-local"
spec:
  import: true
  images:
    - from:
        kind: DockerImage
        name: "${st4sd_registry_url}/st4sd-datastore"
      to:
        name: "${st4sd_tag}"
      referencePolicy:
        type: ""
status: {}
---
kind: ImageStreamImport
apiVersion: image.openshift.io/v1
metadata:
  name: "st4sd-datastore-mongodb"
  namespace: "st4sd-local"
spec:
  import: true
  images:
    - from:
        kind: DockerImage
        name: "${st4sd_registry_url}/st4sd-datastore-mongodb"
      to:
        name: "${st4sd_tag}"
      referencePolicy:
        type: ""
status: {}
EOF
fi
