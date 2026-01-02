# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

ARG AWS_DEFAULT_REGION=us-east-1

FROM 763104351884.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/pytorch-inference:2.6.0-gpu-py312-cu124-ubuntu22.04-ec2

ARG COMMIT=db001d2b2479131bad2d0ee170b75001e9fad076

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install nano -y \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Download ThermoMPNN Code
RUN wget -q -P /tmp "https://github.com/ievapudz/TemStaPro/archive/${COMMIT}.zip" \
    && mkdir -p /home/TemStaPro \
    && unzip /tmp/${COMMIT}.zip -d /tmp \
    && mv /tmp/TemStaPro-${COMMIT}/* /home/TemStaPro \
    && rm -rf /tmp/TemStaPro-${COMMIT}

WORKDIR /home/TemStaPro

COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -U -r /tmp/requirements.txt \
    && rm /tmp/requirements.txt

ENV TMPDIR="/tmp"
ENV PYTHONPATH="/home/TemStaPro:${PYTHONPATH}"

COPY examples /home/TemStaPro/examples

ENTRYPOINT []