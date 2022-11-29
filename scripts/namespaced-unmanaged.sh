#!/bin/bash

# Copyright IBM Inc. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
# Authors:
#  Vassilis Vassiliadis

dirScripts=`dirname "${0}"`
dirCurrent=`pwd`
releaseName="st4sd-namespaced-unmanaged"

# Defaults are
# DEBUG=no
# ST4SD_DEVELOPMENT=no
# CUSTOM_HELM_VALUES=yes
source ${dirScripts}/deploy-common.sh


# VV: This second values file configures the helm-chart. We use it *after* the one that the user specified.
# This way if we make changes to the helm-chart and a user (or CI/CD) updates an existing release
# we can be sure that we're properly configuring the helm chart.
cat << EOF >${injectedConfigPath}
# Unmanaged namespaced objects include Secret, the st4sd-runtime-config and st4sd-registry ConfigMaps.
# We expect that ST4SD admins will manually modify these objects after the
# initial standup of the st4sd services/deployments/etc
EOF

decide_image_tags

echo_options_for_images_and_pull_secrets 'MayInstallSecretsToo' >>${injectedConfigPath}

if  [ "$?" != "0" ]; then
  echo "Could not generate ${injectedConfigPath} (exit code $?)"
  cat "${injectedConfigPath}"
  exit 1
fi

cat << EOF >>${injectedConfigPath}
# Leave the decision for installing the githubSecretOAuth up to the admin
# installGithubSecretOAuth: true
installDatastoreSecretMongoDB: true
installRuntimeServiceConfigMap: true
installRegistryBackendConfigMap: true
installRegistryUINginxConfigMap: true
imagesVariant: "${ST4SD_TAG}"

datastoreMongoDBSecretName: st4sd-datastore-mongodb-credentials

# ---------------------------------------------------
# Some objects should be handled by st4sd-namespace-managed release
installRBACNamespaced: false
installDeployer: false
installWorkflowOperator: false
installDatastore: false
installRuntimeService: false
installRegistryBackend: false
installRegistryUI: false
installAuthentication: false

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

if [ $? -ne 0 ]; then
  echo "helm command failed"
  exit 1
fi

