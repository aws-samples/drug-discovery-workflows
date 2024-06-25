#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
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

[ -z "$ENVIRONMENT" ] && { ENVIRONMENT="main"; }
[ -z "$STACK_NAME" ] && { STACK_NAME="aho-ddw"; }
[ -z "$REGION" ] && { REGION="us-east-1"; }
[ -z "$WAITFORCONTAINER" ] && { WAITFORCONTAINER="N"; }

zip -r build/code.zip * -x .\*/\* -x tests
aws s3 cp build/code.zip s3://$BUCKET_NAME/build/$ENVIRONMENT/code/code.zip
rm build/code.zip

aws cloudformation package --template-file build/cloudformation/root.yaml \
  --output-template build/cloudformation/packaged.yaml --region $REGION \
  --s3-bucket $BUCKET_NAME --s3-prefix build/cloudformation
aws cloudformation deploy --template-file build/cloudformation/packaged.yaml \
  --capabilities CAPABILITY_NAMED_IAM --stack-name $STACK_NAME --region $REGION \
  --parameter-overrides S3BucketName=$BUCKET_NAME Timestamp=$TIMESTAMP \
  WaitForContainerBuild=$WAITFORCONTAINER Environment=$ENVIRONMENT
rm build/cloudformation/packaged.yaml
esm3-sagemaker-sample-notebook