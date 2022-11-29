#!/bin/bash

# Copyright IBM Inc. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
# Authors:
#  Vassilis Vassiliadis

# VV: Print information about current project
oc project

dirScripts=`dirname "${0}"`
dirCurrent=`pwd`
releaseName="st4sd-cluster-scoped"

# Defaults are
# DEBUG=no
# ST4SD_DEVELOPMENT=no
# CUSTOM_HELM_VALUES=yes
source ${dirScripts}/deploy-common.sh

# VV: make sure we have helm values to use
handle_helm_values ${1}

# VV: This second values file configures the helm-chart. We use it *after* the one that the user specified.
# This way if we make changes to the helm-chart and a user (or CI/CD) updates an existing release
# we can be sure that we're properly configuring the helm chart.
cat << EOF >${injectedConfigPath}
# Only install Cluster Scoped RBAC (SecurityContextConstraints and ClusterRoleBinding)
installRBACClusterScoped: true

# All namespaced-scoped objects should be "owned" by a different helm-release.
# Otherwise, we're going to need cluster-admin privileges to modify
# all those namespace-scoped objects below.
installImagePullSecretWorkflowStack: false
installImagePullSecretContribApplications: false
installImagePullSecretCommunityApplications: false
installGithubSecretOAuth: false
installDatastoreSecretMongoDB: false
installRuntimeServiceConfigMap: false
installRegistryBackendConfigMap: false
installRegistryUINginxConfigMap: false
installRBACNamespaced: false
installDeployer: false
installWorkflowOperator: false
installDatastore: false
installRuntimeService: false
installRegistryBackend: false
installRegistryUI: false
installAuthentication: false
EOF
 
chartPath=${dirScripts}/../helm-chart

echo "Will auto-inject following configuration"
cat ${injectedConfigPath}

# VV: install the CustomResourceDefinition (CRD) outside of helm
# helm will only perform the 1st installation of a CRD and will never update it
# we need to use oc/kubectl to manually handle installing/updating it
if [ "${DEBUG}" != "yes" ]; then
  echo Creating Workflow CRD
  oc apply -f ${chartPath}/crd-workflow.yaml

  if [ $? -ne 0 ]; then
    echo "Unable to update CustomResourceDefinition"
    exit 1
  fi
fi

# Extra args come from deploy-common.sh
helm upgrade --install ${extraArgs} --history-max=2 -f ${configPath} -f ${injectedConfigPath} ${releaseName} ${chartPath}

if [ $? -ne 0 ]; then
  echo "helm command failed"
  exit 1
else
  if [ "${DEBUG}" == "yes" ]; then
    cat ${injectedConfigPath}
  fi
  rm ${injectedConfigPath}
fi
