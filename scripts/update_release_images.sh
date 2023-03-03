#!/usr/bin/env bash

# Copyright IBM Inc. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
# Authors:
#  Vassilis Vassiliadis

# VV: See checks below for environment variables that the script expects and their meaning
export DOCKER_REGISTRY_OUT=${DOCKER_REGISTRY_OUT:-${DOCKER_REGISTRY}}

export IMG_NAME_IN_PREFIX=${IMG_NAME_IN_PREFIX:-"/st4sd/official-base/"}
export IMG_NAME_OUT_PREFIX=${IMG_NAME_OUT_PREFIX:-"/st4sd/official-base/"}

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

skopeo login --tls-verify=false -u "${DOCKER_USERNAME}" -p "${DOCKER_TOKEN}" "https://${DOCKER_REGISTRY}"

DOCKER_TOKEN_OUT=${DOCKER_TOKEN_OUT:-${DOCKER_TOKEN}}
DOCKER_USERNAME_OUT=${DOCKER_USERNAME_OUT:-${DOCKER_USERNAME}}

if [[ "${DOCKER_REGISTRY}" != "${DOCKER_REGISTRY_OUT}" ]]; then
  skopeo login --tls-verify=false -u "${DOCKER_USERNAME_OUT}" -p "${DOCKER_TOKEN_OUT}" "https://${DOCKER_REGISTRY_OUT}"
fi


for img in ${images[@]}; do
    img_in=${DOCKER_REGISTRY}${IMG_NAME_IN_PREFIX}${img}:${TAG_SOURCE}
    img_out=${DOCKER_REGISTRY_OUT}${IMG_NAME_OUT_PREFIX}${img}:${TAG_DESTINATION}

    echo "Mirroring ${img_in} --to--> ${img_out}"
    skopeo copy --insecure-policy --src-tls-verify=false --dest-tls-verify=false --multi-arch all --retry-times=5 \
        docker://${img_in}  docker://${img_out}
done

set +x
echo  "Finished mirroring"
for img in ${images[@]}; do
    img_in=${DOCKER_REGISTRY}${IMG_NAME_IN_PREFIX}${img}:${TAG_SOURCE}
    img_out=${DOCKER_REGISTRY_OUT}${IMG_NAME_OUT_PREFIX}${img}:${TAG_DESTINATION}

    echo "${img_in} --mirrored-to--> ${img_out}"
done
