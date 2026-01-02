#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#

############################################################
# Test all workflows deployed by a CloudFormation stack
# 
# This script discovers all HealthOmics workflows tagged with
# a specific StackPrefix and starts test runs for each workflow
# using built-in example inputs from the workflow containers.
#
# NOTE: This tests only the default version of each workflow.
#
## Options
# -n CloudFormation stack name (required)
# -r AWS region (default: us-east-1)
# -v Verbose output (Y/N, default: N)
#
# Example CMD
# ./test_workflows.sh \
#   -n "my-aho-ddw-stack" \
#   -r "us-east-1"

set -e

# Check required commands
if ! command -v aws &>/dev/null; then
  echo "Error: The AWS CLI could not be found. Please visit https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html for installation instructions."
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "Error: jq not found. Please visit https://jqlang.github.io/jq/download/ for installation instructions."
  exit 1
fi

# Parse command line arguments
while getopts 'n:r:v:' OPTION; do
  case "$OPTION" in
  n) STACK_NAME="$OPTARG" ;;
  r) REGION="$OPTARG" ;;
  v) VERBOSE="$OPTARG" ;;
  *) exit 1 ;;
  esac
done

# Set defaults
[ -z "$REGION" ] && { REGION="us-east-1"; }
[ -z "$VERBOSE" ] && { VERBOSE="N"; }

# Validate required parameters
if [ -z "$STACK_NAME" ]; then
  echo "Error: Stack name (-n) is required"
  exit 1
fi

echo "=========================================="
echo "HealthOmics Workflow Test Runner"
echo "=========================================="
echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
echo "=========================================="
echo ""

# Get stack outputs
echo "Retrieving stack outputs..."
STACK_OUTPUTS=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query 'Stacks[0].Outputs' \
  --output json)

if [ -z "$STACK_OUTPUTS" ] || [ "$STACK_OUTPUTS" == "null" ]; then
  echo "Error: Could not retrieve stack outputs. Check that stack '$STACK_NAME' exists in region '$REGION'"
  exit 1
fi

# Extract stack prefix, role ARN, and S3 bucket
STACK_PREFIX=$(echo "$STACK_OUTPUTS" | jq -r '.[] | select(.OutputKey=="StackPrefix") | .OutputValue')
ROLE_ARN=$(echo "$STACK_OUTPUTS" | jq -r '.[] | select(.OutputKey=="OmicsWorkflowRole") | .OutputValue')
S3_BUCKET=$(echo "$STACK_OUTPUTS" | jq -r '.[] | select(.OutputKey=="S3BucketName") | .OutputValue')

if [ -z "$STACK_PREFIX" ] || [ "$STACK_PREFIX" == "null" ]; then
  echo "Error: Could not find StackPrefix in stack outputs"
  exit 1
fi

if [ -z "$ROLE_ARN" ] || [ "$ROLE_ARN" == "null" ]; then
  echo "Error: Could not find OmicsWorkflowRole in stack outputs"
  exit 1
fi

if [ -z "$S3_BUCKET" ] || [ "$S3_BUCKET" == "null" ]; then
  echo "Error: Could not find S3BucketName in stack outputs"
  exit 1
fi

# Get full role ARN
ROLE_ARN=$(aws iam get-role --role-name "$ROLE_ARN" --query 'Role.Arn' --output text --region "$REGION")

# Set output URI to test-outputs folder in stack bucket
OUTPUT_URI="s3://${S3_BUCKET}/test-outputs/"

echo "Stack Prefix: $STACK_PREFIX"
echo "Workflow Role: $ROLE_ARN"
echo "S3 Bucket: $S3_BUCKET"
echo "Output URI: $OUTPUT_URI"
echo ""

# Discover workflows with matching StackPrefix tag
echo "Discovering workflows with StackPrefix tag: $STACK_PREFIX"
WORKFLOWS=$(aws omics list-workflows \
  --region "$REGION" \
  --query "items[?tags.StackPrefix=='$STACK_PREFIX'].[id,name,status]" \
  --output json)

WORKFLOW_COUNT=$(echo "$WORKFLOWS" | jq 'length')

if [ "$WORKFLOW_COUNT" -eq 0 ]; then
  echo "Warning: No workflows found with StackPrefix tag '$STACK_PREFIX'"
  echo "This may indicate:"
  echo "  1. Workflows are still being created by CodeBuild"
  echo "  2. Workflow deployment was disabled during stack creation"
  echo "  3. Stack deployment did not complete successfully"
  exit 0
fi

echo "Found $WORKFLOW_COUNT workflow(s)"
echo ""

# Array to store run IDs
declare -a RUN_IDS=()
declare -a WORKFLOW_NAMES=()

# Function to start a workflow run
start_workflow_run() {
  local workflow_id=$1
  local workflow_name=$2
  local timestamp=$(date +%Y%m%d-%H%M%S)
  local run_name="test-${workflow_name}-${timestamp}"
  
  echo "----------------------------------------"
  echo "Starting test run for: $workflow_name"
  echo "Workflow ID: $workflow_id"
  
  # Start the run
  local run_output=$(aws omics start-run \
    --workflow-id "$workflow_id" \
    --role-arn "$ROLE_ARN" \
    --name "$run_name" \
    --output-uri "${OUTPUT_URI}${run_name}/" \
    --storage-type DYNAMIC \
    --parameters "{}" \
    --region "$REGION" \
    --output json 2>&1)
  
  if [ $? -eq 0 ]; then
    local run_id=$(echo "$run_output" | jq -r '.id')
    local run_arn=$(echo "$run_output" | jq -r '.arn')
    
    echo "✓ Run started successfully"
    echo "  Run ID: $run_id"
    echo "  Run Name: $run_name"
    
    if [ "$VERBOSE" == "Y" ]; then
      echo "  Run ARN: $run_arn"
    fi
    
    RUN_IDS+=("$run_id")
    WORKFLOW_NAMES+=("$workflow_name")
    
    return 0
  else
    echo "✗ Failed to start run"
    echo "  Error: $run_output"
    return 1
  fi
}

# Start runs for all workflows
echo "Starting test runs..."
echo ""

SUCCESS_COUNT=0
FAILURE_COUNT=0

for i in $(seq 0 $((WORKFLOW_COUNT - 1))); do
  WORKFLOW_ID=$(echo "$WORKFLOWS" | jq -r ".[$i][0]")
  WORKFLOW_NAME=$(echo "$WORKFLOWS" | jq -r ".[$i][1]")
  WORKFLOW_STATUS=$(echo "$WORKFLOWS" | jq -r ".[$i][2]")
  
  if [ "$WORKFLOW_STATUS" != "ACTIVE" ]; then
    echo "Skipping $WORKFLOW_NAME (status: $WORKFLOW_STATUS)"
    continue
  fi
  
  if start_workflow_run "$WORKFLOW_ID" "$WORKFLOW_NAME"; then
    ((SUCCESS_COUNT++))
  else
    ((FAILURE_COUNT++))
  fi
  
  echo ""
done

# Summary
echo "=========================================="
echo "Test Run Summary"
echo "=========================================="
echo "Total workflows found: $WORKFLOW_COUNT"
echo "Runs started successfully: $SUCCESS_COUNT"
echo "Runs failed to start: $FAILURE_COUNT"
echo ""

if [ ${#RUN_IDS[@]} -eq 0 ]; then
  echo "No runs were started"
  exit 1
fi

echo "Run IDs:"
for i in "${!RUN_IDS[@]}"; do
  echo "  ${WORKFLOW_NAMES[$i]}: ${RUN_IDS[$i]}"
done
echo ""
echo "=========================================="
echo "Test run complete!"
echo ""
echo "To check run status:"
echo "  aws omics get-run --id <RUN_ID> --region $REGION"
echo ""
echo "To list all runs:"
echo "  aws omics list-runs --region $REGION"
echo "=========================================="
