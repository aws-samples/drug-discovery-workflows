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
#
# Example CMD
# ./deploy.sh \
#   -b "my-deployment-bucket" \
#   -n "my-aho-ddw-stack" \
#   -r "us-east-1" \

set -e
unset -v BUCKET_NAME STACK_NAME REGION TIMESTAMP

TIMESTAMP=$(date +%s)

while getopts 'b:n:r:' OPTION; do
    case "$OPTION" in
    b) BUCKET_NAME="$OPTARG";;
    n) STACK_NAME="$OPTARG";;
    r) REGION="$OPTARG";;       
    *) exit 1 ;;    
    esac
done 

[ -z "$STACK_NAME" ] && { STACK_NAME="aho-ddw"; }
[ -z "$REGION" ] && { INPUT_FILE="us-east-1"; }

zip -r code.zip modules -x .\*/\*
aws s3 cp code.zip s3://$BUCKET_NAME/build/code/code.zip
rm code.zip

aws cloudformation package --template-file cloudformation/root.yaml \
  --output-template cloudformation/packaged.yaml --region $REGION \
  --s3-bucket $BUCKET_NAME --s3-prefix build/cloudformation
aws cloudformation deploy --template-file cloudformation/packaged.yaml \
  --capabilities CAPABILITY_NAMED_IAM --stack-name $STACK_NAME --region $REGION \
  --parameter-overrides S3BucketName=$BUCKET_NAME Timestamp=$TIMESTAMP
rm cloudformation/packaged.yaml