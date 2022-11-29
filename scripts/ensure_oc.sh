#!/usr/bin/env bash

# Copyright IBM Inc. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
# Authors:
#  Vassilis Vassiliadis

# VV: First ensure that oc exists, if not try to fetch it

oc version >/dev/null 2>&1

if [[ $? != 0 ]]; then
    echo "oc is not in PATH, will attempt to fetch it"
    cd /tmp
    wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz

    tar -xvf openshift-client-linux.tar.gz
    rm openshift-client-linux.tar.gz
    chmod +x oc
    mkdir -p /tmp/oc_binaries
    mv oc kubectl /tmp/oc_binaries
    cd -
    export PATH=$PATH:/tmp/oc_binaries

    oc version >/dev/null 2>&1
    if [[ $? != 0 ]]; then
        echo "Failed to fetch oc utilities, is the network down?"
        exit 1
   fi
fi
set -e
echo "oc in PATH"