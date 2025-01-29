# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

ARG AWS_DEFAULT_REGION=us-east-1

FROM 763104351884.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/pytorch-inference:2.5.1-gpu-py311-cu124-ubuntu22.04-ec2
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install additional dependencies from requirements.txt file
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -U -r /tmp/requirements.txt \
    && pip install --no-cache-dir -U --no-deps chai_lab \
    && rm /tmp/requirements.txt

## Cleanup ##
RUN pip cache purge \
    && rm -rf /tmp/tmp* \
    && rm -iRf /root/.cache

COPY scripts/ /home/scripts/
WORKDIR /home/scripts

ENV TMPDIR="/tmp"
# https://pytorch.org/docs/stable/notes/cuda.html#environment-variables
ENV PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

ENTRYPOINT []