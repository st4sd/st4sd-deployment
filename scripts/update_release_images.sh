#!/usr/bin/env bash

# Copyright IBM Inc. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
# Authors:
#  Vassilis Vassiliadis

# VV: See checks below for environment variables that the script expects and their meaning
export DOCKER_REGISTRY_OUT=${DOCKER_REGISTRY_OUT:-${DOCKER_REGISTRY}}

if [[ -z "${DOCKER_USERNAME}" ]]; then
    echo "Expecting DOCKER_USERNAME environment variable (username for skopeo login, e.g. st4sd-robot)"
    exit 1
fi

if [[ -z "${DOCKER_TOKEN}" ]]; then
    echo "Expecting DOCKER_TOKEN environment variable (password for skopeo login, e.g. quay.io API-KEY)"
    exit 1
fi

if [[ -z "${DOCKER_REGISTRY}" ]]; then
    echo "Expecting DOCKER_REGISTRY environment variable (domain of docker registry, e.g quay.io/st4sd/official-base/)"
    exit 1
fi

if [[ -z "${DOCKER_REGISTRY_OUT}" ]]; then
    echo "Expecting DOCKER_REGISTRY_OUT environment variable (domain of docker registry, e.g quay.io/st4sd/official-base/)"
    exit 1
fi

export TAG_SOURCE=${TAG_SOURCE:-release-candidate}
export TAG_DESTINATION=${TAG_DESTINATION:-platform-release-latest}

images=(
  "st4sd-runtime-core"
  "st4sd-runtime-service"
  "st4sd-runtime-k8s" "st4sd-runtime-k8s-input-s3" "st4sd-runtime-k8s-monitoring"
  "st4sd-datastore" "st4sd-datastore-mongodb"
  "st4sd-registry-ui" "st4sd-registry-backend"
)

echo "Will generate ${TAG_DESTINATION} images out of ${TAG_SOURCE} images"

set -ex

skopeo login --tls-verify=false -u ${DOCKER_USERNAME} -p ${DOCKER_TOKEN} https://${DOCKER_REGISTRY}

for img in ${images[@]}; do
    skopeo copy --insecure-policy --tls-verify=false --multi-arch all \
        docker://${DOCKER_REGISTRY}/${img}:${TAG_SOURCE} \
        docker://${DOCKER_REGISTRY_OUT}/${img}:${TAG_DESTINATION}
done

set +x
echo  "Finished generating ${TAG_DESTINATION} images out of ${TAG_SOURCE} images"
for img in ${images[@]}; do
    echo "  ${DOCKER_REGISTRY}/${img}:${TAG_DESTINATION}"
done
