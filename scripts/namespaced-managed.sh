#!/bin/bash

# Copyright IBM Inc. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
# Authors:
#  Vassilis Vassiliadis

# VV: Print information about current project
releaseName="st4sd-namespaced-managed"
dirScripts=`dirname "${0}"`
dirCurrent=`pwd`

# Defaults are
# DEBUG=no
# ST4SD_DEVELOPMENT=no
# CUSTOM_HELM_VALUES=yes
source ${dirScripts}/deploy-common.sh

# VV: This second values file configures the helm-chart. We use it *after* the one that the user specified.
# This way if we make changes to the helm-chart and a user (or CI/CD) updates an existing release
# we can be sure that we're properly configuring the helm chart.

decide_image_tags

echo "# Auto-configuration for deploying ${releaseName}" >${injectedConfigPath}

echo_options_for_images_and_pull_secrets '' >>${injectedConfigPath}

if  [ "$?" != "0" ]; then
  echo "Could not generate ${injectedConfigPath} (exit code $?)"
  cat "${injectedConfigPath}"
  exit 1
fi

cat << EOF >>${injectedConfigPath}
installRBACNamespaced: true
installDeployer: true
installWorkflowOperator: true
installDatastore: true
installRuntimeService: true
installRegistryBackend: true
installRegistryUI: true
installAuthentication: true

# Configuration
imagesVariant: "${ST4SD_TAG}"
useImageStreamTags: ${ST4SD_USE_IMAGE_STREAM_TAGS}

# ---------------------------------------------------
# These are part of st4sd-namespaced-unmanaged
installImagePullSecretWorkflowStack: false
installImagePullSecretContribApplications: false
installImagePullSecretCommunityApplications: false
installGithubSecretOAuth: false
installDatastoreSecretMongoDB: false
installRuntimeServiceConfigMap: false
installRegistryBackendConfigMap: false
installRegistryUINginxConfigMap: false

# Some objects should be handled by st4sd-cluster-scoped
installRBACClusterScoped: false
EOF

echo "Will auto-inject following configuration"
cat ${injectedConfigPath}


# VV: make sure we have helm values to use
handle_helm_values ${1}


chartPath=${dirScripts}/../helm-chart

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

if [ "${DEBUG}" != "yes" ]; then
  ${dirScripts}/trigger_deployment_configs.sh
fi
