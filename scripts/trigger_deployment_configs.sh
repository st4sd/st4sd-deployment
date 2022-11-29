#!/usr/bin/env bash

# Copyright IBM Inc. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
# Authors:
#  Vassilis Vassiliadis

export ST4SD_TAG=${ST4SD_TAG:-":platform-release-latest"}
export RESTART_MONGODB=${RESTART_MONGODB:-"no"}

# VV: set these 2 if they are unset - adding `:-` changes operation to "if empty OR unset"
export ST4SD_IMAGES_OFFICIAL_BASE_REGISTRY=${ST4SD_IMAGES_OFFICIAL_BASE_REGISTRY-quay.io/st4sd}
export ST4SD_IMAGES_OFFICIAL_BASE_PREFIX=${ST4SD_IMAGES_OFFICIAL_BASE_PREFIX-official-base/}

if [ "${ST4SD_DEVELOPMENT}" != "yes" ]; then
  echo "Creating the ST4SD pods using ${ST4SD_TAG} containers"

  reg_url="${ST4SD_IMAGES_OFFICIAL_BASE_REGISTRY}"

  if [ "${reg_url: -1}" != "/" ]; then
    reg_url="${reg_url}/"
  fi

  reg_prefix="${ST4SD_IMAGES_OFFICIAL_BASE_PREFIX}"
  reg_prefix="${reg_url}${reg_prefix}"

  echo "Importing images from ${reg_prefix}"

  oc import-image st4sd-datastore-mongodb${ST4SD_TAG} --from=${reg_prefix}st4sd-datastore-mongodb${ST4SD_TAG} --confirm
  oc import-image st4sd-runtime-k8s${ST4SD_TAG} --from=${reg_prefix}st4sd-runtime-k8s${ST4SD_TAG} --confirm
  oc import-image st4sd-datastore${ST4SD_TAG} --from=${reg_prefix}st4sd-datastore${ST4SD_TAG} --confirm
  oc import-image st4sd-runtime-service${ST4SD_TAG} --from=${reg_prefix}st4sd-runtime-service${ST4SD_TAG} --confirm
  oc import-image st4sd-registry-backend${ST4SD_TAG} --from=${reg_prefix}st4sd-registry-backend${ST4SD_TAG} --confirm
  oc import-image st4sd-registry-ui${ST4SD_TAG} --from=${reg_prefix}st4sd-registry-ui${ST4SD_TAG} --confirm
else
  # To update the Development pods all we need to do is delete them so that they get rescheduled
  echo "Deleting ST4SD deployment pods to cause them to be re-created"
  oc delete pod --wait=false -ldeploymentconfig=st4sd-authentication
  oc delete pod --wait=false -ldeploymentconfig=st4sd-runtime-service
  oc delete pod --wait=false -ldeploymentconfig=st4sd-datastore-cloud-instance
  oc delete pod --wait=false -ldeploymentconfig=st4sd-datastore-nexus
  oc delete pod --wait=false -ldeploymentconfig=st4sd-runtime-k8s
  oc delete pod --wait=false -ldeploymentconfig=st4sd-registry-backend
  oc delete pod --wait=false -ldeploymentconfig=st4sd-registry-ui
  # Restarting MongoDB may result in data-loss under weird edge-cases. Thankfully, there's rarely
  # the need to restart the mongoDB pod, so just avoid automating this step for now.
  # If you do want to re-create the pod, then uncomment the line below

  if [ "${RESTART_MONGODB}" == "yes" ]; then
    oc delete pod --wait=false -ldeploymentconfig=st4sd-datastore-mongodb
  else
    echo "If you want to also restart the mongoDB pod then execute the below line - when in doubt do not restart it"
    echo "oc delete pod -ldeploymentconfig=st4sd-datastore-mongodb"
  fi
fi