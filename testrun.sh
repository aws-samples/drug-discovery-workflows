#!/bin/bash

# usage: ./testrun.sh -w WORKFLOW_NAME -a ACCOUNT_ID -r REGION -o OMICS_EXECUTION_ROLE -b OUTPUT_BUCKET -p PARAMETERS [-g RUN_GROUP_ID]

set -ex
unset -v TIMESTAMP WORKFLOW_NAME ACCOUNT_ID REGION OMICS_EXECUTION_ROLE OUTPUT_BUCKET PARAMETERS RUN_GROUP_ID

TIMESTAMP=$(date +%s)

# Source environment variables from .aws/env if it exists
if [ -f ".aws/env" ]; then
  source .aws/env
fi

# Set variables from arguments if they are not already set
while getopts 'w:a:r:o:b:p:g:' OPTION; do
  case "$OPTION" in
  w) WORKFLOW_NAME="$OPTARG" ;;
  a) [ -z "$ACCOUNT_ID" ] && ACCOUNT_ID="$OPTARG" ;;
  r) [ -z "$REGION" ] && REGION="$OPTARG" ;;
  o) [ -z "$OMICS_EXECUTION_ROLE" ] && OMICS_EXECUTION_ROLE="$OPTARG" ;;
  b) [ -z "$OUTPUT_BUCKET" ] && OUTPUT_BUCKET="$OPTARG" ;;
  p) PARAMETERS="$OPTARG" ;;
  g) [ -z "$RUN_GROUP_ID" ] && RUN_GROUP_ID="$OPTARG" ;;
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

# rfdiffusion is the only workflow name that is 1:1 with container name
if [ "$WORKFLOW_NAME" != "rfdiffusion" ]; then  
  pushd containers
  bash ../workflows/$WORKFLOW_NAME/build_containers.sh $REGION $ACCOUNT_ID develop
  popd
else
  docker build \
    --platform linux/amd64 \
    -t $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$WORKFLOW_NAME:develop \
    -f containers/$WORKFLOW_NAME/Dockerfile containers/$WORKFLOW_NAME

  docker push $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$WORKFLOW_NAME:develop
fi

# Package the workflow
mkdir -p tmp/workflows/$WORKFLOW_NAME tmp/modules

pushd tmp

cp -r ../workflows/$WORKFLOW_NAME/* workflows/$WORKFLOW_NAME
cp -r ../modules/* modules

sed -i "" -E "s/[0-9]{12}\.dkr\.ecr\.(us-[a-z]*-[0-9])/$ACCOUNT_ID.dkr.ecr.$REGION/g" ./workflows/$WORKFLOW_NAME/*.config workflows/$WORKFLOW_NAME/*.wdl 2>/dev/null || true
sed -i "" -E "s/[0-9]{12}\.dkr\.ecr\.(us-[a-z]*-[0-9])/$ACCOUNT_ID.dkr.ecr.$REGION/g" ./workflows/$WORKFLOW_NAME/*.config workflows/$WORKFLOW_NAME/*.nf 2>/dev/null || true
sed -i "" -E "s/[0-9]{12}\.dkr\.ecr\.(us-[a-z]*-[0-9])/$ACCOUNT_ID.dkr.ecr.$REGION/g" ./workflows/$WORKFLOW_NAME/*.config workflows/$WORKFLOW_NAME/*.config 2>/dev/null || true

zip -r drug-discovery-workflows.zip .

popd

# Create the workflow
workflow_id=$(aws omics create-workflow --engine NEXTFLOW --name $WORKFLOW_NAME-dev-$TIMESTAMP --region $REGION --cli-input-yaml file://tmp/workflows/$WORKFLOW_NAME/config.yaml --definition-zip fileb://tmp/drug-discovery-workflows.zip --main workflows/$WORKFLOW_NAME/main.nf --query 'id' --output text)
aws omics wait workflow-active --region $REGION --id $workflow_id

# Run the workflow
start_run_command="aws omics start-run \
    --retention-mode REMOVE \
    --storage-type DYNAMIC \
    --workflow-id $workflow_id \
    --name $WORKFLOW_NAME-dev-$TIMESTAMP \
    --role-arn \"$OMICS_EXECUTION_ROLE\" \
    --parameters \"$PARAMETERS\" \
    --region $REGION \
    --output-uri s3://$OUTPUT_BUCKET/out"

# Add run-group-id if provided
if [ -n "$RUN_GROUP_ID" ]; then
  start_run_command+=" --run-group-id $RUN_GROUP_ID"
fi

# Execute the start-run command
eval $start_run_command

# Cleanup
rm -rf tmp
