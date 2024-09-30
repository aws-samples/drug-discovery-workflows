#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#

############################################################
# Download data into the S3 bucket associated to your DDW stack
#
# Example CMD
# ./download.sh https://mywebsite/data.csv

set -e

TIMESTAMP=$(date +%s)

err() {
    echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
}

if ! command -v aws &>/dev/null; then
    err "Error: The AWS CLI could not be found. Please visit https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html for installation instructions."
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "Error: jq not found. Please visit https://jqlang.github.io/jq/download/ for installation instructions."
    exit 1
fi

DOWNLOAD_PROJECT=$(cat stack-outputs.json | jq -r '.[] | select(.OutputKey=="CodeBuildDownloadProjectName") | .OutputValue')
REF_DATA_URI=$(cat stack-outputs.json | jq -r '.[] | select(.OutputKey=="StackRefDataURI") | .OutputValue')

echo "Submitting AWS CodeBuild job to download $1 to $REF_DATA_URI"
aws codebuild start-build \
    --project-name $DOWNLOAD_PROJECT \
    --environment-variables-override name="SOURCE_URI",value=$1,type="PLAINTEXT" name="DESTINATION_URI",value=$REF_DATA_URI,type="PLAINTEXT" |
    jq -r '.build'
