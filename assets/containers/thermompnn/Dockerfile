# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

ARG AWS_DEFAULT_REGION=us-east-1

FROM 763104351884.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/pytorch-inference:2.2.0-gpu-py310-cu118-ubuntu20.04-ec2
ARG COMMIT=13569795daa7689b6a6df0279b383e08c6212e79

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install nano -y \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Download ThermoMPNN Code
RUN wget -q -P /tmp "https://github.com/Kuhlman-Lab/ThermoMPNN/archive/${COMMIT}.zip" \
    && mkdir -p /home/thermompnn \
    && unzip /tmp/${COMMIT}.zip -d /tmp \
    && mv /tmp/ThermoMPNN-${COMMIT}/* /home/thermompnn \
    && rm -rf /tmp/ThermoMPNN-${COMMIT} \
    && cp /home/thermompnn/*.py /home/thermompnn/analysis \
    && touch "/home/thermompnn/analysis/__init__.py"

COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -U -r /tmp/requirements.txt \
    && rm /tmp/requirements.txt

WORKDIR /home/thermompnn/analysis
COPY predict.py /home/thermompnn/analysis/predict.py
COPY local.yaml /home/thermompnn/analysis/local.yaml
ENV TMPDIR="/tmp"
ENV PYTHONPATH="/home/thermompnn/analysis:${PYTHONPATH}"

ENTRYPOINT []