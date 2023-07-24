#!/bin/bash

# load env variables from shell
set -a

az deployment sub show -n docusaurus-aca-yaml > /tmp/deployment_output.json

# if $version define use it for $VERSION_CONTAINER otherwise put local
export DOCS_VERSION=${RELEASE:-local}
export APPNAME=$(jq -r '.properties.outputs.apiIdentityName.value' /tmp/deployment_output.json)
export RG=$(jq -r '.properties.outputs.resourceGroupName.value' /tmp/deployment_output.json)
export MANAGED_ENVIRONMENT_ID=$(jq -r '.properties.outputs.managedEnvironmentId.value' /tmp/deployment_output.json)
export MANAGED_IDENTITY_ID=$(jq -r '.properties.outputs.apiIdentityId.value' /tmp/deployment_output.json)
export REGISTRYNAME=$(jq -r '.properties.outputs.containerRegistryName.value' /tmp/deployment_output.json)

envsubst < ci/deployment.template.yaml > ci/deployment.yaml
