#!/bin/bash

# usage: ./testrun.sh -w WORKFLOW_NAME -a ACCOUNT_ID -r REGION -o OMICS_EXECUTION_ROLE -b OUTPUT_BUCKET

set -ex
unset -v TIMESTAMP WORKFLOW_NAME ACCOUNT_ID REGION OMICS_EXECUTION_ROLE OUTPUT_BUCKET

TIMESTAMP=$(date +%s)

# set variables
while getopts 'w:a:r:o:b:' OPTION; do
  case "$OPTION" in
  w) WORKFLOW_NAME="$OPTARG" ;;
  a) ACCOUNT_ID="$OPTARG" ;;
  r) REGION="$OPTARG" ;;
  o) OMICS_EXECUTION_ROLE="$OPTARG" ;;
  b) OUTPUT_BUCKET="$OPTARG" ;;
  *) exit 1 ;;
  esac
done

# Check if the required variables are set
if [ -z "$WORKFLOW_NAME" ] || [ -z "$ACCOUNT_ID" ] || [ -z "$REGION" ] || [ -z "$OMICS_EXECUTION_ROLE" ] || [ -z "$OUTPUT_BUCKET" ]; then
  echo "Error: Missing required arguments."
  echo "Usage: $0 -w WORKFLOW_NAME -a ACCOUNT_ID -r REGION"
  exit 1
fi

# Login to ECR
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

# Build and push Docker image to ECR
docker build \
    --platform linux/amd64 \
    -t $WORKFLOW_NAME:latest \
    -f containers/$WORKFLOW_NAME/Dockerfile containers/$WORKFLOW_NAME
docker tag $WORKFLOW_NAME:latest $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$WORKFLOW_NAME:develop
docker push $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$WORKFLOW_NAME:develop

# Package the workflow
mkdir -p tmp/$WORKFLOW_NAME
cp -r workflows/$WORKFLOW_NAME/* tmp/$WORKFLOW_NAME
sed -i='' "s/{{\s*\([A-Za-z0-9_-]*:[A-Za-z0-9_-]*\)\s*}}/$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com\/\1/g" tmp/$WORKFLOW_NAME/*.wdl 2>/dev/null || true
sed -i='' "s/{{\s*\([A-Za-z0-9_-]*:[A-Za-z0-9_-]*\)\s*}}/$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com\/\1/g" tmp/$WORKFLOW_NAME/*.nf 2>/dev/null || true
sed -i='' "s/{{\s*\([A-Za-z0-9_-]*:[A-Za-z0-9_-]*\)\s*}}/$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com\/\1/g" tmp/$WORKFLOW_NAME/*.config 2>/dev/null || true
zip -j -r tmp/$WORKFLOW_NAME/workflow.zip tmp/$WORKFLOW_NAME

# Create the workflow
workflow_id=$(aws omics create-workflow --engine NEXTFLOW --name $WORKFLOW_NAME-dev-$TIMESTAMP --region $REGION --cli-input-yaml file://tmp/$WORKFLOW_NAME/config.yaml --definition-zip fileb://tmp/$WORKFLOW_NAME/workflow.zip --query 'id' --output text)
aws omics wait workflow-active --region $REGION --id $workflow_id

# Run the workflow
aws omics start-run \
    --retention-mode REMOVE \
    --workflow-id $workflow_id \
    --name $WORKFLOW_NAME-dev-$TIMESTAMP \
    --role-arn "$OMICS_EXECUTION_ROLE" \
    --parameters file://tmp/$WORKFLOW_NAME/params.json \
    --region $REGION \
    --output-uri s3://$OUTPUT_BUCKET/out

# Cleanup
rm -rf tmp/$WORKFLOW_NAME
