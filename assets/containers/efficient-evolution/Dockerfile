FROM public.ecr.aws/ubuntu/ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

ARG MINICONDA_VERSION=Miniconda3-py39_25.1.1-2-Linux-x86_64
ARG PYTHON_VERSION=3.9
ARG EFFICIENT_EVOLUTION_VERSION=e9e8f610a5b4b3f48515741323209232faaf5039

# Update package lists and install required packages
RUN apt-get update && apt-get install -y \
    curl \
    git \
    wget \
    unzip \
    tree \
    && rm -rf /var/lib/apt/lists/*

# Install Miniconda and Python
# https://repo.anaconda.com/miniconda/
RUN curl -O https://repo.anaconda.com/miniconda/${MINICONDA_VERSION}.sh \
    && bash ${MINICONDA_VERSION}.sh -f -b -p /opt/miniconda \
    && rm ${MINICONDA_VERSION}.sh

# Set up environment variables
ENV PATH=/opt/miniconda/bin:$PATH
ENV PYTHONPATH=/opt/miniconda/lib/python${PYTHON_VERSION}/site-packages:$PYTHONPATH

WORKDIR /opt

# Install 
RUN git clone https://github.com/brianhie/efficient-evolution.git

WORKDIR /opt/efficient-evolution

RUN git checkout ${EFFICIENT_EVOLUTION_VERSION}

RUN conda env create --name efficient-evolution --file environment.yml

# Set default environment
ENV PATH=/opt/miniconda/envs/efficient-evolution/bin:$PATH


CMD ["/bin/bash"]
