FROM public.ecr.aws/ubuntu/ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

ARG MINICONDA_VERSION=Miniconda2-py27_4.8.3-Linux-x86_64
ARG AGGRESCAN3D_VERSION=1.0.2
ARG CABS_VERSION=0.9.14
ARG PYTHON_VERSION=2.7

# Update package lists and install required packages
RUN apt-get update && apt-get install -y \
    curl \
    git \
    wget \
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

# Install Aggrescan3D
RUN conda install -c lcbio aggrescan3d=${AGGRESCAN3D_VERSION}

# FoldX (optional) ommited due to licensing issues

# Install CABS-flex
RUN apt-get update && apt-get install gfortran csh -y && rm -rf /var/lib/apt/lists/*

# Omited modeller due to licensing issues
# RUN conda install -c salilab modeller

RUN conda install -c lcbio cabs=${CABS_VERSION}

# Fixes 'ImportError: Failed to import any qt binding' error
RUN mkdir -p ~/.config/matplotlib && echo "backend: Agg" > ~/.config/matplotlib/matplotlibrc
