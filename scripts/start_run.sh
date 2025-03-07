#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#

############################################################
# Start an AWS Omics workflows run 

# Example CMD
# ./start_run.sh \
#   -n "my-aho-ddw-stack" \
#   -w "chai-1" \
#   -i \
#    '{
#        "roleArn": "arn:aws:iam::123456789123:role/aho-dd-abcgdkfle-OmicsWorkflowRole",
#        "name": "my-run",
#        "parameters": {
#           "fasta_file": "s3://my-bucket/input/TEST.fasta"
#        },
#        "storageType": "DYNAMIC",
#        "outputUri": "s3://my-bucket/input/outputs/"
#    }'  

set -e

