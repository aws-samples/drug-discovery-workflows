#!/bin/bash

# usage: ./scripts/testrun.sh -c CONTAINER_NAME -w WORKFLOW_NAME -a ACCOUNT_ID -r REGION -o OMICS_EXECUTION_ROLE -b OUTPUT_BUCKET -p PARAMETERS [-g RUN_GROUP_ID]

set -ex
unset -v TIMESTAMP CONTAINER_NAME WORKFLOW_NAME ACCOUNT_ID REGION OMICS_EXECUTION_ROLE OUTPUT_BUCKET PARAMETERS RUN_GROUP_ID

if ! command -v aws &>/dev/null; then
  echo "Error: The AWS CLI could not be found. Please visit https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html for installation instructions."
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "Error: jq not found. Please visit https://jqlang.github.io/jq/download/ for installation instructions."
  exit 1
fi

TIMESTAMP=$(date +%s)

# Source environment variables from .aws/env if it exists
if [ -f ".aws/env" ]; then
  source .aws/env
fi

# Set variables from arguments if they are not already set
while getopts 'c:w:a:r:o:b:p:g:' OPTION; do
  case "$OPTION" in
  c) CONTAINER_NAME="$OPTARG" ;;
  w) WORKFLOW_NAME="$OPTARG" ;;
  a) [ -z "$ACCOUNT_ID" ] && ACCOUNT_ID="$OPTARG" ;;
  r) [ -z "$REGION" ] && REGION="$OPTARG" ;;
  o) [ -z "$OMICS_EXECUTION_ROLE" ] && OMICS_EXECUTION_ROLE="$OPTARG" ;;
  b) [ -z "$OUTPUT_BUCKET" ] && OUTPUT_BUCKET="$OPTARG" ;;
  f) [ -z "$REF_DATA_BUCKET" ] && REF_DATA_BUCKET="$OPTARG" ;;
  p) PARAMETERS="$OPTARG" ;;
  g) [ -z "$RUN_GROUP_ID" ] && RUN_GROUP_ID="$OPTARG" ;;
  *) exit 1 ;;
  esac
done

# Check if the required variables are set
if [ -c "$CONTAINER_NAME" ] || [ -z "$WORKFLOW_NAME" ] || [ -z "$ACCOUNT_ID" ] || [ -z "$REGION" ] || [ -z "$OMICS_EXECUTION_ROLE" ] || [ -z "$OUTPUT_BUCKET" ] || [ -z "$PARAMETERS" ]; then
  echo "Error: Missing required arguments."
  echo "Usage: $0 -c CONTAINER_NAME -w WORKFLOW_NAME -a ACCOUNT_ID -r REGION -o OMICS_EXECUTION_ROLE -b OUTPUT_BUCKET -p PARAMETERS"
  exit 1
fi

# Login to ECR
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin 763104351884.dkr.ecr.$REGION.amazonaws.com # Deep Learning Container

docker build \
  --platform linux/amd64 \
  -t $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$CONTAINER_NAME:develop \
  -f assets/containers/$CONTAINER_NAME/Dockerfile assets/containers/$CONTAINER_NAME

if aws ecr describe-repositories --repository-names $CONTAINER_NAME >/dev/null 2>$?; then
  echo "Repository $CONTAINER_NAME exists."
else
  echo "Repository $CONTAINER_NAME does not exist, creating..."
  aws ecr create-repository --repository-name $CONTAINER_NAME >/dev/null
  aws ecr set-repository-policy --repository-name $CONTAINER_NAME --policy-text '{"Version":"2012-10-17","Statement":[{"Sid":"omics workflow","Effect":"Allow","Principal":{"Service":"omics.amazonaws.com"},"Action":["ecr:GetDownloadUrlForLayer","ecr:BatchGetImage","ecr:BatchCheckLayerAvailability"]}]}' >/dev/null
fi

docker push $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$CONTAINER_NAME:develop

# Package the workflow
mkdir -p tmp/assets/workflows/$WORKFLOW_NAME

pushd tmp

cp -r ../assets/workflows/$WORKFLOW_NAME/* assets/workflows/$WORKFLOW_NAME

# Replace ECR URLs (legacy config)
sed -i "" -E "s/[0-9]{12}\.dkr\.ecr\.(us-[a-z]*-[0-9])/$ACCOUNT_ID.dkr.ecr.$REGION/g" ./assets/workflows/$WORKFLOW_NAME/*.config assets/workflows/$WORKFLOW_NAME/*.wdl 2>/dev/null || true
sed -i "" -E "s/[0-9]{12}\.dkr\.ecr\.(us-[a-z]*-[0-9])/$ACCOUNT_ID.dkr.ecr.$REGION/g" ./assets/workflows/$WORKFLOW_NAME/*.config assets/workflows/$WORKFLOW_NAME/*.nf 2>/dev/null || true
sed -i "" -E "s/[0-9]{12}\.dkr\.ecr\.(us-[a-z]*-[0-9])/$ACCOUNT_ID.dkr.ecr.$REGION/g" ./assets/workflows/$WORKFLOW_NAME/*.config assets/workflows/$WORKFLOW_NAME/*.config 2>/dev/null || true

# Replace {{S3_BUCKET_NAME}} and container strings like {{openfold:latest}}
# Always use develop tag in this script
sed -i='' "s/{{\s*\([A-Za-z0-9_-]*\):[A-Za-z0-9_-]*\s*}}/$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com\/\1:develop/g" ./assets/workflows/$WORKFLOW_NAME/*.config 2>/dev/null || true
sed -i='' "s/{{S3_BUCKET_NAME}}/$REF_DATA_BUCKET/g" ./assets/workflows/$WORKFLOW_NAME/*.config 2>/dev/null || true

zip -r drug-discovery-workflows.zip .

popd

# Create the workflow
workflow_id=$(aws omics create-workflow --engine NEXTFLOW --name $WORKFLOW_NAME-dev-$TIMESTAMP --region $REGION --cli-input-yaml file://tmp/assets/workflows/$WORKFLOW_NAME/config.yaml --definition-zip fileb://tmp/drug-discovery-workflows.zip --main assets/workflows/$WORKFLOW_NAME/main.nf --query 'id' --output text)
aws omics wait workflow-active --region $REGION --id $workflow_id

# Run the workflow
start_run_command="aws omics start-run \
    --retention-mode REMOVE \
    --storage-type STATIC \
    --storage-capacity 9600 \
    --workflow-id $workflow_id \
    --name $WORKFLOW_NAME-dev-$TIMESTAMP \
    --role-arn $OMICS_EXECUTION_ROLE \
    --parameters $PARAMETERS \
    --region $REGION \
    --output-uri s3://$OUTPUT_BUCKET/out \
    --query id --output text"

# Add run-group-id if provided
if [ -n "$RUN_GROUP_ID" ]; then
  start_run_command+=" --run-group-id $RUN_GROUP_ID"
fi

# Execute the start-run command
run_id=$(eval $start_run_command)
aws omics get-run --id $run_id --region $REGION | jq '{"id", "status"}'

# Cleanup
rm -rf tmp
