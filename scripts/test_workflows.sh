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

# Trap Ctrl+C and other signals for clean exit
trap 'echo ""; echo "Script interrupted by user"; exit 130' INT TERM

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

# First, get all workflows
ALL_WORKFLOWS=$(aws omics list-workflows \
  --region "$REGION" \
  --query "items[].[id,name,status,arn]" \
  --output json)

# Filter workflows by checking tags for each one
WORKFLOWS="[]"
WORKFLOW_NUM=0
TOTAL_WORKFLOWS=$(echo "$ALL_WORKFLOWS" | jq 'length')

while IFS= read -r workflow; do
  ((WORKFLOW_NUM++))
  WORKFLOW_ARN=$(echo "$workflow" | jq -r '.[3]')
  
  # Rate limiting: sleep between API calls to avoid throttling
  sleep 0.2
  
  # Get tags for this workflow with retry logic
  RETRY_COUNT=0
  MAX_RETRIES=3
  TAGS=""
  
  while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    TAGS=$(aws omics list-tags-for-resource \
      --resource-arn "$WORKFLOW_ARN" \
      --region "$REGION" \
      --output json 2>&1)
    
    if [ $? -eq 0 ]; then
      break
    elif echo "$TAGS" | grep -q "ThrottlingException"; then
      ((RETRY_COUNT++))
      if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
        echo "  Throttled while checking workflow $WORKFLOW_NUM/$TOTAL_WORKFLOWS, retrying in 2s..."
        sleep 2
      fi
    else
      # Other error, use empty tags
      TAGS='{"tags":{}}'
      break
    fi
  done
  
  if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "  Warning: Failed to get tags for workflow after $MAX_RETRIES retries, skipping"
    continue
  fi
  
  # Check if StackPrefix tag matches
  TAG_VALUE=$(echo "$TAGS" | jq -r --arg prefix "$STACK_PREFIX" '.tags.StackPrefix // empty')
  
  if [ "$TAG_VALUE" == "$STACK_PREFIX" ]; then
    # Add this workflow to our filtered list (without ARN)
    WORKFLOW_INFO=$(echo "$workflow" | jq '[.[0], .[1], .[2]]')
    WORKFLOWS=$(echo "$WORKFLOWS" | jq --argjson wf "$WORKFLOW_INFO" '. += [$wf]')
  fi
done < <(echo "$ALL_WORKFLOWS" | jq -c '.[]')

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

# Function to check if workflow has required parameters
check_required_params() {
  local workflow_id=$1
  
  if [ "$VERBOSE" == "Y" ]; then
    echo "  Checking parameter template..."
  fi
  
  # Rate limiting
  sleep 0.2
  
  # Get workflow details including parameter template with retry logic
  local retry_count=0
  local max_retries=3
  local workflow_details=""
  
  while [ $retry_count -lt $max_retries ]; do
    # Run with background process and timeout for cross-platform compatibility
    workflow_details=$(aws omics get-workflow \
      --id "$workflow_id" \
      --region "$REGION" \
      --cli-read-timeout 30 \
      --cli-connect-timeout 10 \
      --output json 2>&1)
    
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
      break
    elif echo "$workflow_details" | grep -q "ThrottlingException"; then
      ((retry_count++))
      if [ $retry_count -lt $max_retries ]; then
        echo "  Throttled, retrying in 2s..."
        sleep 2
      fi
    elif echo "$workflow_details" | grep -q -E "(timed out|timeout|ReadTimeout)"; then
      ((retry_count++))
      if [ $retry_count -lt $max_retries ]; then
        echo "  Timed out, retrying in 2s..."
        sleep 2
      fi
    else
      # Other error - assume no parameter template, allow run to proceed
      if [ "$VERBOSE" == "Y" ]; then
        echo "  Could not get workflow details, assuming no required params"
      fi
      return 1
    fi
  done
  
  if [ $retry_count -eq $max_retries ]; then
    echo "  Warning: Failed to get workflow details after retries, assuming no required params"
    return 1
  fi
  
  # Check if there are any required parameters (optional=false)
  local has_required=$(echo "$workflow_details" | jq -r '
    .parameterTemplate // {} | 
    to_entries | 
    map(select(.value.optional == false)) | 
    length > 0
  ')
  
  if [ "$has_required" == "true" ]; then
    return 0  # Has required params
  else
    return 1  # No required params
  fi
}

# Function to start a workflow run
start_workflow_run() {
  local workflow_id=$1
  local workflow_name=$2
  local timestamp=$(date +%Y%m%d-%H%M%S)
  local run_name="test-${workflow_name}-${timestamp}"
  
  echo "----------------------------------------"
  echo "Starting test run for: $workflow_name"
  echo "Workflow ID: $workflow_id"
  
  # Check if workflow has required parameters
  if check_required_params "$workflow_id"; then
    echo "⊘ Skipping - workflow has required parameters"
    echo "  Use workflow-specific params.json to test this workflow"
    return 2  # Special return code for skipped
  fi
  
  if [ "$VERBOSE" == "Y" ]; then
    echo "  Starting run with timeout protection..."
  fi
  
  # Rate limiting before start-run - increase to 10 seconds to avoid throttling
  sleep 10
  
  # Start the run with retry logic
  local retry_count=0
  local max_retries=3
  local run_output=""
  
  while [ $retry_count -lt $max_retries ]; do
    if [ "$VERBOSE" == "Y" ]; then
      echo "  Calling aws omics start-run (attempt $((retry_count + 1))/$max_retries)..."
    fi
    
    # Use background process with manual timeout for reliability
    local temp_file=$(mktemp)
    (
      aws omics start-run \
        --workflow-id "$workflow_id" \
        --role-arn "$ROLE_ARN" \
        --name "$run_name" \
        --output-uri "${OUTPUT_URI}${run_name}/" \
        --storage-type DYNAMIC \
        --parameters "{}" \
        --region "$REGION" \
        --output json 2>&1 > "$temp_file"
    ) &
    local pid=$!
    
    # Wait for up to 60 seconds with progress indicator
    local wait_time=0
    local max_wait=60
    while kill -0 $pid 2>/dev/null && [ $wait_time -lt $max_wait ]; do
      sleep 1
      ((wait_time++))
      if [ "$VERBOSE" == "Y" ] && [ $((wait_time % 10)) -eq 0 ]; then
        echo "  Waiting... ${wait_time}s elapsed"
      fi
    done
    
    # Check if process is still running
    if kill -0 $pid 2>/dev/null; then
      # Process timed out, kill it
      if [ "$VERBOSE" == "Y" ]; then
        echo "  Process timed out, killing..."
      fi
      kill -9 $pid 2>/dev/null
      wait $pid 2>/dev/null
      rm -f "$temp_file"
      
      ((retry_count++))
      if [ $retry_count -lt $max_retries ]; then
        echo "  Timed out after ${max_wait}s, retrying... (attempt $((retry_count + 1))/$max_retries)"
        sleep 5
      fi
      continue
    fi
    
    # Process completed, get exit code
    wait $pid
    local exit_code=$?
    run_output=$(cat "$temp_file")
    rm -f "$temp_file"
    
    if [ "$VERBOSE" == "Y" ]; then
      echo "  Exit code: $exit_code"
    fi
    
    if [ $exit_code -eq 0 ]; then
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
    elif echo "$run_output" | grep -q "ThrottlingException"; then
      ((retry_count++))
      if [ $retry_count -lt $max_retries ]; then
        echo "  Throttled, retrying in 5s... (attempt $((retry_count + 1))/$max_retries)"
        sleep 5
      fi
    else
      # Other error, don't retry
      echo "✗ Failed to start run"
      if [ "$VERBOSE" == "Y" ]; then
        echo "  Error: $run_output"
      else
        echo "  Error: $(echo "$run_output" | head -n 1)"
      fi
      return 1
    fi
  done
  
  if [ $retry_count -eq $max_retries ]; then
    echo "✗ Failed to start run after $max_retries retries"
    return 1
  fi
}

# Start runs for all workflows
echo "Starting test runs..."
echo ""

SUCCESS_COUNT=0
FAILURE_COUNT=0
SKIPPED_COUNT=0

for i in $(seq 0 $((WORKFLOW_COUNT - 1))); do
  WORKFLOW_ID=$(echo "$WORKFLOWS" | jq -r ".[$i][0]")
  WORKFLOW_NAME=$(echo "$WORKFLOWS" | jq -r ".[$i][1]")
  WORKFLOW_STATUS=$(echo "$WORKFLOWS" | jq -r ".[$i][2]")
  
  if [ "$WORKFLOW_STATUS" != "ACTIVE" ]; then
    echo "Skipping $WORKFLOW_NAME (status: $WORKFLOW_STATUS)"
    ((SKIPPED_COUNT++))
    continue
  fi
  
  start_workflow_run "$WORKFLOW_ID" "$WORKFLOW_NAME"
  RESULT=$?
  
  if [ $RESULT -eq 0 ]; then
    ((SUCCESS_COUNT++))
  elif [ $RESULT -eq 2 ]; then
    ((SKIPPED_COUNT++))
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
echo "Runs skipped (required params): $SKIPPED_COUNT"
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
