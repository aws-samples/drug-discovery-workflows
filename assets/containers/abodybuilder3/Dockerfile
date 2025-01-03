# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

ARG AWS_DEFAULT_REGION=us-east-1

FROM 763104351884.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/pytorch-inference:2.4.0-gpu-py311-cu124-ubuntu22.04-ec2

COPY requirements.txt /tmp/requirements.txt

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && mamba install -c bioconda -c conda-forge openmm pdbfixer anarci -y \
    && pip install --no-cache-dir -U -r /tmp/requirements.txt \
    && pip install --no-cache-dir --no-deps 'abodybuilder3@git+https://github.com/Exscientia/abodybuilder3.git' \
    && rm /tmp/requirements.txt \
    && pip cache purge \
    && rm -rf /tmp/tmp* \
    && rm -iRf /root/.cache

COPY scripts/ /home/scripts/
WORKDIR /home/scripts

ENV TMPDIR="/tmp"

ENTRYPOINT []