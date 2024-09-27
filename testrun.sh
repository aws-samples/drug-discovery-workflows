#!/bin/bash

# usage: ./testrun.sh -w WORKFLOW_NAME -a ACCOUNT_ID -r REGION -o OMICS_EXECUTION_ROLE -b OUTPUT_BUCKET -p PARAMETERS

set -ex
unset -v TIMESTAMP WORKFLOW_NAME ACCOUNT_ID REGION OMICS_EXECUTION_ROLE OUTPUT_BUCKET PARAMETERS

TIMESTAMP=$(date +%s)

# Source environment variables from .aws/env if it exists
if [ -f ".aws/env" ]; then
  source .aws/env
fi

# Set variables from arguments if they are not already set
while getopts 'w:a:r:o:b:p:' OPTION; do
  case "$OPTION" in
  w) WORKFLOW_NAME="$OPTARG" ;;
  a) [ -z "$ACCOUNT_ID" ] && ACCOUNT_ID="$OPTARG" ;;
  r) [ -z "$REGION" ] && REGION="$OPTARG" ;;
  o) [ -z "$OMICS_EXECUTION_ROLE" ] && OMICS_EXECUTION_ROLE="$OPTARG" ;;
  b) [ -z "$OUTPUT_BUCKET" ] && OUTPUT_BUCKET="$OPTARG" ;;
  p) PARAMETERS="$OPTARG" ;;
  *) exit 1 ;;
  esac
done

# Check if the required variables are set
if [ -z "$WORKFLOW_NAME" ] || [ -z "$ACCOUNT_ID" ] || [ -z "$REGION" ] || [ -z "$OMICS_EXECUTION_ROLE" ] || [ -z "$OUTPUT_BUCKET" ] || [ -z "$PARAMETERS" ]; then
  echo "Error: Missing required arguments."
  echo "Usage: $0 -w WORKFLOW_NAME -a ACCOUNT_ID -r REGION -o OMICS_EXECUTION_ROLE -b OUTPUT_BUCKET -p PARAMETERS"
  exit 1
fi

# Login to ECR
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

# Build and push Docker image to ECR
output=$(docker build \
    --platform linux/amd64 \
    -t $WORKFLOW_NAME:latest \
    -f containers/$WORKFLOW_NAME/Dockerfile containers/$WORKFLOW_NAME 2>&1 || true)

# Check if the error message is in the output
# If it is, fall back to executing the workflows/$WORKFLOW_NAME/build_containers.sh script
if echo "$output" | grep -q "ERROR: unable to prepare context: path \"containers/$WORKFLOW_NAME\" not found"; then
  echo "Context not found. Running the build_containers.sh script..."
  
  pushd containers
  bash ../workflows/$WORKFLOW_NAME/build_containers.sh $REGION $ACCOUNT_ID
  popd
fi

# Package the workflow
mkdir -p tmp/$WORKFLOW_NAME
cp -r workflows/$WORKFLOW_NAME/* tmp/$WORKFLOW_NAME
sed -i "" -E "s/[0-9]{12}\.dkr\.ecr\.(us-[a-z]*-[0-9])/$ACCOUNT_ID.dkr.ecr.$REGION/g" ./tmp/rfdiffusion/*.config tmp/$WORKFLOW_NAME/*.wdl 2>/dev/null || true
sed -i "" -E "s/[0-9]{12}\.dkr\.ecr\.(us-[a-z]*-[0-9])/$ACCOUNT_ID.dkr.ecr.$REGION/g" ./tmp/rfdiffusion/*.config tmp/$WORKFLOW_NAME/*.nf 2>/dev/null || true
sed -i "" -E "s/[0-9]{12}\.dkr\.ecr\.(us-[a-z]*-[0-9])/$ACCOUNT_ID.dkr.ecr.$REGION/g" ./tmp/rfdiffusion/*.config tmp/$WORKFLOW_NAME/*.config 2>/dev/null || true
zip -j -r tmp/$WORKFLOW_NAME/workflow.zip tmp/$WORKFLOW_NAME

# Create the workflow
workflow_id=$(aws omics create-workflow --engine NEXTFLOW --name $WORKFLOW_NAME-dev-$TIMESTAMP --region $REGION --cli-input-yaml file://tmp/$WORKFLOW_NAME/config.yaml --definition-zip fileb://tmp/$WORKFLOW_NAME/workflow.zip --query 'id' --output text)
aws omics wait workflow-active --region $REGION --id $workflow_id

# Run the workflow
aws omics start-run \
    --retention-mode REMOVE \
    --storage-type DYNAMIC \
    --workflow-id $workflow_id \
    --name $WORKFLOW_NAME-dev-$TIMESTAMP \
    --role-arn "$OMICS_EXECUTION_ROLE" \
    --parameters "$PARAMETERS" \
    --region $REGION \
    --output-uri s3://$OUTPUT_BUCKET/out

# Cleanup
rm -rf tmp
