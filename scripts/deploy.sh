#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#

############################################################
# Deploy the architecture for the Amazon HealthOmics Drug Discovery Workflows
# into your AWS account
## Options
# -b S3 bucket name to use for deployment staging
# -n CloudFormation stack name
# -r Deployment region
# -w Wait for container build to complete before deployment?
#
# Example CMD
# ./deploy.sh \
#   -b "my-deployment-bucket" \
#   -n "my-aho-ddw-stack" \
#   -r "us-east-1" \
#   -w "Y"

set -e
unset -v BUCKET_NAME ENVIRONMENT STACK_NAME REGION TIMESTAMP WAITFORCONTAINER

TIMESTAMP=$(date +%s)

if ! command -v aws &>/dev/null; then
  echo "Error: The AWS CLI could not be found. Please visit https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html for installation instructions."
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "Error: jq not found. Please visit https://jqlang.github.io/jq/download/ for installation instructions."
  exit 1
fi

while getopts 'b:e:n:r:w:' OPTION; do
  case "$OPTION" in
  b) BUCKET_NAME="$OPTARG" ;;
  e) ENVIRONMENT="$OPTARG" ;;
  n) STACK_NAME="$OPTARG" ;;
  r) REGION="$OPTARG" ;;
  w) WAITFORCONTAINER="$OPTARG" ;;
  *) exit 1 ;;
  esac
done

[ -z "$ENVIRONMENT" ] && { ENVIRONMENT="dev"; }
[ -z "$STACK_NAME" ] && { STACK_NAME="aho-ddw"; }
[ -z "$REGION" ] && { REGION="us-east-1"; }
[ -z "$WAITFORCONTAINER" ] && { WAITFORCONTAINER="N"; }

zip -r build/code.zip build assets -x .\*/\* -x tests
aws s3 cp build/code.zip s3://$BUCKET_NAME/build/$ENVIRONMENT/code/code.zip
rm build/code.zip

aws cloudformation package --template-file build/cloudformation/root.yaml \
  --output-template build/cloudformation/packaged.yaml --region $REGION \
  --s3-bucket $BUCKET_NAME --s3-prefix build/cloudformation
aws cloudformation deploy --template-file build/cloudformation/packaged.yaml \
  --capabilities CAPABILITY_NAMED_IAM --stack-name $STACK_NAME --region $REGION \
  --parameter-overrides S3BucketName=$BUCKET_NAME Timestamp=$TIMESTAMP \
  WaitForContainerBuild=$WAITFORCONTAINER Environment=$ENVIRONMENT
aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION |
  jq -r '.Stacks[0].Outputs' |
  tee stack-outputs.json |
  jq

rm build/cloudformation/packaged.yaml