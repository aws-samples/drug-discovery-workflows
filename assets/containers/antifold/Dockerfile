# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

ARG AWS_DEFAULT_REGION=us-east-1

FROM 763104351884.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/pytorch-inference:2.4.0-gpu-py311-cu124-ubuntu22.04-ec2

# Make environment and install dependencies
RUN conda create --name antifold python=3.10 -y
# activate environment
RUN echo "source activate antifold" > ~/.bashrc
ENV VIRTUAL_ENV=/opt/conda/envs/antifold
ENV PATH=/opt/conda/envs/antifold/bin:$PATH
# install AntiFold from source
RUN git clone https://github.com/oxpig/AntiFold && cd AntiFold && pip install .

WORKDIR /AntiFold
ENTRYPOINT []