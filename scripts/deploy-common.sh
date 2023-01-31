#!/usr/bin/env bash

# Copyright IBM Inc. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
# Authors:
#  Vassilis Vassiliadis

# Defaults are
# DEBUG=no
# ST4SD_DEVELOPMENT=no
# CUSTOM_HELM_VALUES=yes
# ST4SD_USE_PUBLIC_IMAGES=yes

if [ -z "${releaseName}" ]; then
  echo "releaseName is unset"
  exit 1
fi

configPath=${dirCurrent}/${releaseName}.yaml
injectedConfigPath=`mktemp ${dirCurrent}/injected-${releaseName}-yaml-XXXXX`

# VV: If set to `yes` (default is `yes`) then install the public and open-source version of ST4SD.
# Otherwise, install the internal version of ST4SD (requires the creation and use of
# imagePullSecrets for all ST4SD images)
export ST4SD_USE_PUBLIC_IMAGES=${ST4SD_USE_PUBLIC_IMAGES:-"yes"}

export ST4SD_PUBLIC_IMAGES_REGISTRY_URL="quay.io/st4sd/official-base"

# VV: If set to `yes` then it expects one cmdline argument with the path to
# the `deployment-options.yaml` file
# Otherwise, it just uses the default values of the helm chart on an initial install,
# or the existing helm release on an update
export CUSTOM_HELM_VALUES=${CUSTOM_HELM_VALUES:-"yes"}

# VV: If set to yes, installs the DEVELOPMENT version (no imageStreamTags, :latest)
# Otherwise, it installs the production version with imageStreamTags
export ST4SD_DEVELOPMENT=${ST4SD_DEVELOPMENT:-no}

export DEBUG=${DEBUG-no}

if [ "${DEBUG}" == "yes" ]; then
  echo "DEBUG is set - will not actually deploy. Helm will NOT contact the kubernetes server when not installing."
  echo "      The manifests helm prints may not be the ones you would get if you installed the helm chart."
  echo "      See helm-chart/_helpers.tpl for methods that the helm-chart uses to extract information from Kubernetes"
  extraArgs="--debug --dry-run"
else
  extraArgs=""
fi

function rewrite_url() {
  img=$1
  new_registry_url=$2

  # registry_url="${img%/*}"
  image_name="${img##*/}"

  if [ "${new_registry_url: -1}" == "/" ]; then
    new_registry_url="${new_registry_url%?}"
  fi

  echo "${new_registry_url}/${image_name}"
}

function echo_options_for_images_and_pull_secrets() {
  # VV: Set $1 to MayInstallSecretsToo to inspect environment variables and decide whether to install secrets
  options=${1}

  export ST4SD_INSTALL_IMAGE_PULL_SECRET_OFFICIAL_BASE=${ST4SD_INSTALL_IMAGE_PULL_SECRET_OFFICIAL_BASE:-"no"}
  export ST4SD_INSTALL_IMAGE_PULL_SECRET_CONTRIB_APPS=${ST4SD_INSTALL_IMAGE_PULL_SECRET_CONTRIB_APPS:-"no"}
  export ST4SD_INSTALL_IMAGE_PULL_SECRET_COMMUNITY_APPS=${ST4SD_INSTALL_IMAGE_PULL_SECRET_COMMUNITY_APPS:-"no"}

  export ST4SD_IMAGES_OFFICIAL_BASE_REGISTRY=${ST4SD_IMAGES_OFFICIAL_BASE_REGISTRY:-"quay.io"}
  export ST4SD_IMAGES_OFFICIAL_BASE_PREFIX=${ST4SD_IMAGES_OFFICIAL_BASE_PREFIX:-"st4sd/official-base/"}
  export ST4SD_IMAGES_CONTRIB_APPLICATIONS_REGISTRY=${ST4SD_IMAGES_CONTRIB_APPLICATIONS_REGISTRY:-"quay.io"}
  export ST4SD_IMAGES_COMMUNITY_APPLICATIONS_REGISTRY=${ST4SD_IMAGES_COMMUNITY_APPLICATIONS_REGISTRY:-"quay.io"}

  # VV: if we're installing open-source version, and we have not explicitly configured
  # whether to create imagePullSecrets or not, THEN do not create secrets
  # If we're using the internal Images and we have not explicitly configured
  # whether to create imagePullSecrets or not, THEN do create secrets
  if [ "${ST4SD_USE_PUBLIC_IMAGES}" == "yes" ]; then
    image_pull_secret_default="no"
  else
    image_pull_secret_default="yes"
  fi

  if [ -z "${ST4SD_INSTALL_IMAGE_PULL_SECRET_OFFICIAL_BASE}" ]; then
    export ST4SD_INSTALL_IMAGE_PULL_SECRET_OFFICIAL_BASE="${image_pull_secret_default}"
  fi

  if [ -z "${ST4SD_INSTALL_IMAGE_PULL_SECRET_CONTRIB_APPS}" ]; then
    export ST4SD_INSTALL_IMAGE_PULL_SECRET_CONTRIB_APPS="${image_pull_secret_default}"
  fi

  if [ -z "${ST4SD_INSTALL_IMAGE_PULL_SECRET_COMMUNITY_APPS}" ]; then
    export ST4SD_INSTALL_IMAGE_PULL_SECRET_COMMUNITY_APPS="${image_pull_secret_default}"
  fi

  image_pull_secret_stack="false"
  if [ "${ST4SD_INSTALL_IMAGE_PULL_SECRET_OFFICIAL_BASE}" == "yes" ]; then
    image_pull_secret_stack="true"
  fi

  image_pull_secret_contrib_apps="false"
  if [ "${ST4SD_INSTALL_IMAGE_PULL_SECRET_CONTRIB_APPS}" == "yes" ]; then
    image_pull_secret_contrib_apps="true"
  fi

  image_pull_secret_community_apps="false"
  if [ "${ST4SD_INSTALL_IMAGE_PULL_SECRET_COMMUNITY_APPS}" == "yes" ]; then
    image_pull_secret_community_apps="true"
  fi

  # VV: A bit of sanity checking
  if [ "${image_pull_secret_stack}" == 'true' ] && [ -z "${ST4SD_IMAGES_OFFICIAL_BASE_REGISTRY}" ]; then
    echo "#ERROR: ST4SD_INSTALL_IMAGE_PULL_SECRET_OFFICIAL_BASE=yes but no ST4SD_IMAGES_OFFICIAL_BASE_REGISTRY" 1>&2
    exit 1
  fi

  if [ "${image_pull_secret_contrib_apps}" == 'true' ] && [ -z "${ST4SD_IMAGES_CONTRIB_APPLICATIONS_REGISTRY}" ]; then
    echo "#ERROR: ST4SD_INSTALL_IMAGE_PULL_SECRET_CONTRIB_APPS=yes but no ST4SD_IMAGES_CONTRIB_APPLICATIONS_REGISTRY" 1>&2
    exit 1
  fi

  if [ "${image_pull_secret_community_apps}" == 'true' ] && [ -z "${ST4SD_IMAGES_COMMUNITY_APPLICATIONS_REGISTRY}" ]; then
    echo "#ERROR: ST4SD_INSTALL_IMAGE_PULL_SECRET_CONTRIB_APPS=yes but no ST4SD_IMAGES_COMMUNITY_APPLICATIONS_REGISTRY" 1>&2
    exit 1
  fi

  cat <<EOF
useImagePullSecretWorkflowStack: ${image_pull_secret_stack}
useImagePullSecretContribApplications: ${image_pull_secret_contrib_apps}
useImagePullSecretCommunityApplications: ${image_pull_secret_community_apps}
EOF

  if [ "${1}" == "MayInstallSecretsToo" ]; then 
cat <<EOF
installImagePullSecretWorkflowStack: ${image_pull_secret_stack}
installImagePullSecretContribApplications: ${image_pull_secret_contrib_apps}
installImagePullSecretCommunityApplications: ${image_pull_secret_community_apps}
EOF
  else
cat <<EOF
installImagePullSecretWorkflowStack: false
installImagePullSecretContribApplications: false
installImagePullSecretCommunityApplications: false
EOF
  fi

  if [ "${ST4SD_USE_PUBLIC_IMAGES}" != "yes" ]; then
      if [ -z ${ST4SD_IMAGES_OFFICIAL_BASE_REGISTRY} ]; then
        echo "#ERROR: ST4SD_USE_PUBLIC_IMAGES==yes but no ST4SD_IMAGES_OFFICIAL_BASE_REGISTRY" 1>&2
        exit 1
      fi

    reg_url="${ST4SD_IMAGES_OFFICIAL_BASE_REGISTRY}"

    if [ "${reg_url: -1}" != "/" ]; then
      reg_url="${reg_url}/"
    fi

    reg_prefix="${reg_url}${ST4SD_IMAGES_OFFICIAL_BASE_PREFIX}"
    cat <<EOF
imagesRuntimeCore: $(rewrite_url st4sd-runtime-core ${reg_prefix})
imagesDatastoreMongoDB: $(rewrite_url st4sd-datastore-mongodb ${reg_prefix})
imagesRuntimeMonitoring: $(rewrite_url st4sd-runtime-k8s-monitoring ${reg_prefix})
imagesRuntimeS3Fetch: $(rewrite_url st4sd-runtime-k8s-input-s3 ${reg_prefix})
imagesRuntimeOperator: $(rewrite_url st4sd-runtime-k8s ${reg_prefix})
imagesRuntimeService: $(rewrite_url st4sd-runtime-service ${reg_prefix})
imagesDatastore: $(rewrite_url st4sd-datastore ${reg_prefix})
imagesRegistryBackend: $(rewrite_url st4sd-registry-backend ${reg_prefix})
imagesRegistryUI: $(rewrite_url st4sd-registry-ui ${reg_prefix})
EOF

  else
    public_base_images="quay.io/st4sd/official-base"
    cat <<EOF
imagesRuntimeCore: ${public_base_images}/st4sd-datastore-core
imagesDatastoreMongoDB: ${public_base_images}/st4sd-datastore-mongodb
imagesRuntimeMonitoring: ${public_base_images}/st4sd-runtime-k8s-monitoring
imagesRuntimeS3Fetch: ${public_base_images}/st4sd-runtime-k8s-input-s3
imagesRuntimeOperator: ${public_base_images}/st4sd-runtime-k8s
imagesRuntimeService: ${public_base_images}/st4sd-runtime-service
imagesDatastore: ${public_base_images}/st4sd-datastore
imagesRegistryBackend: ${public_base_images}/st4sd-registry-backend
imagesRegistryUI: ${public_base_images}/st4sd-registry-ui
EOF
  fi

  echo "# Private registries start"

  if [ ! -z "${ST4SD_IMAGES_OFFICIAL_BASE_REGISTRY}" ]; then
    cat<<EOF
imagePullSecretWorkflowStackRegistryURL: ${ST4SD_IMAGES_OFFICIAL_BASE_REGISTRY}
EOF
  fi

  if [ ! -z "${ST4SD_IMAGES_CONTRIB_APPLICATIONS_REGISTRY}" ]; then
    cat<<EOF
imagePullSecretContribApplicationsRegistryURL: ${ST4SD_IMAGES_CONTRIB_APPLICATIONS_REGISTRY}
EOF
  fi

  if [ ! -z "${ST4SD_IMAGES_COMMUNITY_APPLICATIONS_REGISTRY}" ]; then
    cat<<EOF
imagePullSecretCommunityApplicationsRegistryURL: ${ST4SD_IMAGES_COMMUNITY_APPLICATIONS_REGISTRY}
EOF
  fi

  echo "# Private registries stop"
}

function decide_image_tags() {
  if [ "${ST4SD_DEVELOPMENT}" == "yes" ]; then
    echo "Deploying the DEVELOPMENT version of ST4SD"
    export ST4SD_TAG=${ST4SD_TAG:-":latest"}
    export ST4SD_USE_IMAGE_STREAM_TAGS="false"
  else
    echo "Deploying the PRODUCTION version of ST4SD"
    export ST4SD_TAG=${ST4SD_TAG:-":platform-release-latest"}
    export ST4SD_USE_IMAGE_STREAM_TAGS="true"
  fi
}

function handle_helm_values() {
  # VV: The development images are frequently updated and might be garbage collected by the
  # Container Registry so the safest way to deploy the DEV environments is not to use imageStreamTags
  if [ "${CUSTOM_HELM_VALUES}" == "yes" ]; then
    if [ "${1}" == "" ]; then
      echo "CUSTOM_HELM_VALUES is set to \"yes\", you must provide path to YAML file with helm values" 1>&2
      exit 1
    fi

    echo "Using helm values under ${1}"
    oc project
    pathToDeploymentOptions=${1}
    cp ${pathToDeploymentOptions} ${configPath}
    if [ $? -ne 0 ]; then
      echo "Unable to copy ${pathToDeploymentOptions} to ${dirScripts}/${releaseName}.yaml" 1>&2
      exit 1
    fi
  else
    echo "Using default/existing HELM values"
    oc project

    helm get values "${releaseName}" --output yaml >${configPath}
  fi
}

