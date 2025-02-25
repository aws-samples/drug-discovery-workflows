FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# Set ARGs for dependency versions
ARG APBS_VERSION=3.4.1
ARG MINICONDA_VERSION=Miniconda3-py39_24.11.1-0-Linux-x86_64
ARG PYTHON_VERSION=3.9
ARG ANARCI_VERSION=2024.05.21
ARG HMMER_VERSION=3.3.2
ARG PEP_PATCH_VERSION=0.2.0

# Update package lists and install required packages
RUN apt-get update && apt-get install -y \
    curl \
    git \
    wget \
    unzip \
    tree \
    build-essential \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Install g++-11
RUN add-apt-repository -y ppa:ubuntu-toolchain-r/test
RUN apt-get update && apt-get install -y g++-11 \
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

# Install ANARCI
RUN conda install -c conda-forge biopython=1.85 -y \
    && conda install -c bioconda anarci=${ANARCI_VERSION} hmmer=${HMMER_VERSION} -y

# Install APBS
RUN wget https://github.com/Electrostatics/apbs/releases/download/v${APBS_VERSION}/APBS-${APBS_VERSION}.Linux.zip \
    && unzip APBS-${APBS_VERSION}.Linux.zip \
    && rm APBS-${APBS_VERSION}.Linux.zip
ENV LD_LIBRARY_PATH=/opt/APBS-${APBS_VERSION}.Linux/lib:${LD_LIBRARY_PATH}
ENV PATH=/opt/APBS-${APBS_VERSION}.Linux/bin:${PATH}

# Install PEP-Patch
RUN git clone https://github.com/liedllab/surface_analyses.git


WORKDIR /opt/surface_analyses

# v0.2.0
RUN git checkout v${PEP_PATCH_VERSION}

COPY requirements.txt .
COPY setup.py .

RUN pip install .

CMD ["/bin/bash"]
