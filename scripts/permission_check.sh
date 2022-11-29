#!/bin/bash

# Copyright IBM Inc. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
# Authors:
#  Alexander Harrison

## Hacky bash-script to quickly check if the OC user has enough permissions to install ST4SD


## verb actions that are needed
verbs=(
get
list
delete
create)

## Kinds that above verbs need to be applied to. Taken using:
##   $ cat template/*/*.yaml | grep kind | egrep -v '^ '
kinds=(
ClusterRole
ClusterRoleBinding
ConfigMap
CustomResourceDefinition
DeploymentConfig
ImageStream
Role
RoleBinding
Route
SecurityContextConstraints
Service
ServiceAccount
#SystemGroup
)


## list-of-forbiddens, to summarise for user at the end
forbidden=()


## Loop through all combinations
for kind in ${kinds[@]}
do
    for verb in ${verbs[@]}
    do
        allowed=`oc auth can-i ${verb} ${kind}`
        echo "[$verb] for [$kind]: ${allowed}"
        if [ "${allowed}" = "no" ]
        then
            forbidden+=("${verb}_${kind}")
        fi
    done
    echo ""
done

## Summarised forbidden stuff
echo "User does not have following permissions:"
for entry in ${forbidden[@]}
do
    echo " -> ${entry//_/ }"
done
