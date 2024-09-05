#!/bin/bash

# usage: ./testrun.sh <workflow_name>

set -e
unset -v WORKFLOW_NAME ACCOUNT_ID REGION TIMESTAMP

TIMESTAMP=$(date +%s)

# set variables
while getopts 'w:a:r:' OPTION; do
  case "$OPTION" in
  w) WORKFLOW_NAME="$OPTARG" ;;
  a) ACCOUNT_ID="$OPTARG" ;;
  r) REGION="$OPTARG" ;;
  *) exit 1 ;;
  esac
done

# Login to ECR
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

# build and push Docker image to ECR
docker build \
    --platform linux/amd64 \
    -t $WORKFLOW_NAME:latest \
    -f containers/$WORKFLOW_NAME/Dockerfile containers/$WORKFLOW_NAME
docker tag $WORKFLOW_NAME:latest $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$WORKFLOW_NAME:latest
docker push $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$WORKFLOW_NAME:latest

# Package the workflow
mkdir -p tmp/$WORKFLOW_NAME
cp -r workflows/$WORKFLOW_NAME/* tmp/$WORKFLOW_NAME
sed -i='' "s/{{\s*\([A-Za-z0-9_-]*:[A-Za-z0-9_-]*\)\s*}}/$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com\/\1/g" tmp/$WORKFLOW_NAME/*.wdl 2>/dev/null || true
sed -i='' "s/{{\s*\([A-Za-z0-9_-]*:[A-Za-z0-9_-]*\)\s*}}/$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com\/\1/g" tmp/$WORKFLOW_NAME/*.nf 2>/dev/null || true
sed -i='' "s/{{\s*\([A-Za-z0-9_-]*:[A-Za-z0-9_-]*\)\s*}}/$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com\/\1/g" tmp/$WORKFLOW_NAME/*.config 2>/dev/null || true
zip -j -r tmp/$WORKFLOW_NAME/workflow.zip tmp/$WORKFLOW_NAME

# Create the workflow
aws omics create-workflow --name $WORKFLOW_NAME-dev-$TIMESTAMP --region $REGION --cli-input-yaml file://tmp/$WORKFLOW_NAME/config.yaml --definition-zip fileb://tmp/$WORKFLOW_NAME/workflow.zip

# Run the workflow
# TODO

# Cleanup
rm -rf tmp/$WORKFLOW_NAME

