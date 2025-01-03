# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

ARG AWS_DEFAULT_REGION=us-east-1
FROM 763104351884.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/pytorch-inference:2.4.0-gpu-py311-cu124-ubuntu22.04-ec2

# ARG RFDIFFUSION_COMMIT="b44206a2a79f219bb1a649ea50603a284c225050"
ARG RFDIFFUSION_COMMIT="142930960dd5905403b0d6fd90696fe40650a128"
ARG PROTEINMPNN_COMMIT="8907e6671bfbfc92303b5f79c4b5e6ce47cdef57"

COPY requirements.txt /opt
COPY scripts /opt/scripts

RUN apt-get update \
  && apt-get upgrade -y \
  && apt-get install uuid -y \
  && apt-get autoremove -y \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* \
# Install ProteinMPNN
  && wget -q -P /tmp "https://github.com/dauparas/ProteinMPNN/archive/${PROTEINMPNN_COMMIT}.zip" \
  && mkdir -p /opt/proteinmpnn \
  && unzip /tmp/${PROTEINMPNN_COMMIT}.zip -d /tmp \
  && mv /tmp/ProteinMPNN-${PROTEINMPNN_COMMIT}/* /opt/proteinmpnn \
  && mkdir -p /opt/proteinmpnn/output \
# Install RFDiffusion
  # && wget -q -P /tmp "https://github.com/RosettaCommons/RFdiffusion/archive/${RFDIFFUSION_COMMIT}.zip" \
  && wget -q -P /tmp "https://github.com/brianloyal/RFdiffusion/archive/${RFDIFFUSION_COMMIT}.zip" \
  && mkdir -p /opt/rfdiffusion \
  && unzip /tmp/${RFDIFFUSION_COMMIT}.zip -d /tmp \
  && mv /tmp/RFdiffusion-${RFDIFFUSION_COMMIT}/* /opt/rfdiffusion \
  && mkdir -p /opt/rfdiffusion/output \
# Install pip packages.
  && pip3 install --upgrade --no-cache-dir pip \
  && pip3 install --no-cache-dir -r /opt/requirements.txt \
  && pip3 install --no-cache-dir dgl -f https://data.dgl.ai/wheels/torch-2.4/cu124/repo.html \
  && pip3 install --no-cache-dir /opt/rfdiffusion/env/SE3Transformer \
  && pip3 install --no-cache-dir --no-deps /opt/rfdiffusion

WORKDIR /opt

ENV DGLBACKEND="pytorch"

ENTRYPOINT []