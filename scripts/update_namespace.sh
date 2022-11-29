#!/usr/bin/env bash

# Copyright IBM Inc. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
# Authors:
#  Vassilis Vassiliadis

export PATH=$PATH:/tmp/oc_binaries
export ST4SD_DEVELOPMENT=${ST4SD_DEVELOPMENT:-"no"}
export ST4SD_TAG=${ST4SD_TAG:-":platform-release-latest"}
export RESTART_MONGODB=${RESTART_MONGODB:-"no"}

dirScripts=`dirname "${0}"`

if [[ -z "$NAMESPACE_TARGET" ]]; then
    echo "Need NAMESPACE_TARGET environment variable"
    exit 1
fi

if [[ -z "$IMAGE_TAG" ]]; then
    echo "Need IMAGE_TAG environment variable"
    exit 1
fi

if [[ -z "$OC_LOGIN_URL" ]]; then
    echo "Need OC_LOGIN_USERNAME environment variable"
    exit 1
fi

if [[ -z "$OC_LOGIN_TOKEN" ]]; then
    echo "Need OC_LOGIN_TOKEN environment variable"
    exit 1
fi

${dirScripts}/ensure_oc.sh
wget https://get.helm.sh/helm-v3.8.2-linux-amd64.tar.gz
tar -xvf helm-v3.8.2-linux-amd64.tar.gz
export PATH=$PATH:`pwd`/linux-amd64

echo "Path is ${PATH}"

oc version
helm version

oc login "${OC_LOGIN_URL}" --token "${OC_LOGIN_TOKEN}" --insecure-skip-tls-verify=true

oc project ${NAMESPACE_TARGET}

export CUSTOM_HELM_VALUES="no"

export ST4SD_USE_PUBLIC_IMAGES=${ST4SD_USE_PUBLIC_IMAGES:-"yes"}

export ST4SD_INSTALL_IMAGE_PULL_SECRET_OFFICIAL_BASE=${ST4SD_INSTALL_IMAGE_PULL_SECRET_OFFICIAL_BASE:-"yes"}
export ST4SD_INSTALL_IMAGE_PULL_SECRET_CONTRIB_APPS=${ST4SD_INSTALL_IMAGE_PULL_SECRET_CONTRIB_APPS:-"yes"}
export ST4SD_INSTALL_IMAGE_PULL_SECRET_COMMUNITY_APPS=${ST4SD_INSTALL_IMAGE_PULL_SECRET_COMMUNITY_APPS:-"yes"}

export ST4SD_IMAGES_OFFICIAL_BASE_REGISTRY=res-st4sd-team-official-base-docker-local.artifactory.swg-devops.com
export ST4SD_IMAGES_OFFICIAL_BASE_PREFIX=${ST4SD_IMAGES_OFFICIAL_BASE_PREFIX:-""}
export ST4SD_IMAGES_CONTRIB_APPLICATIONS_REGISTRY=res-st4sd-team-contrib-applications-docker-local.artifactory.swg-devops.com
export ST4SD_IMAGES_COMMUNITY_APPLICATIONS_REGISTRY=res-st4sd-community-team-applications-docker-virtual.artifactory.swg-devops.com

${dirScripts}/namespaced-managed.sh
