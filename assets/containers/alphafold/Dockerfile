# Copyright 2023 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

FROM public.ecr.aws/amazonlinux/amazonlinux:2023 AS build

RUN yum upgrade -y \
  && yum install -y \
  cmake \
  cmake3 \
  gcc \
  gcc-c++ \
  git \
  glibc-static \
  gzip \
  make \
  tar \
  unzip \
  zlib-devel \
  wget \
  zstd \
  bzip2-devel \
  openssl-devel \
  libffi-devel \
  && yum clean all \
  && rm -rf /var/cache/yum

# Compile HHsuite from source
RUN git clone --branch v3.3.0 https://github.com/soedinglab/hh-suite.git /tmp/hh-suite \
  && mkdir /tmp/hh-suite/build \
  && pushd /tmp/hh-suite/build \
  && cmake -DHAVE_AVX2=1 -DCMAKE_INSTALL_PREFIX=/opt/hhsuite .. \
  && make -j 4 && make install \
  && ln -s /opt/hhsuite/bin/* /usr/bin \
  && popd \
  && rm -rf /tmp/hh-suite

# Compile kalign2 from source
RUN pushd /tmp && \
  wget http://msa.sbc.su.se/downloads/kalign/current.tar.gz --no-check-certificate \
  && mkdir -p /tmp/kalign2/build \
  && tar -xvzf current.tar.gz -C /tmp/kalign2 \
  && pushd /tmp/kalign2 \
  && ./configure \
  && make && make install \
  && popd \
  && rm -rf /tmp/kalign2 && \
  popd

# ADD hmmer.tar.gz /tmp/hmmer
RUN mkdir -p /tmp/hmmer && wget -O hmmer.tar.gz  http://eddylab.org/software/hmmer/hmmer-3.4.tar.gz \
  && tar xvzf hmmer.tar.gz -C /tmp/hmmer
RUN pushd /tmp/hmmer/hmmer-* \
  && ./configure \
  && make && make install \
  && popd

# Install Python 3.8.20
RUN yum groupinstall -y "Development Tools" && \
    wget https://www.python.org/ftp/python/3.8.20/Python-3.8.20.tgz && \
    tar xzf Python-3.8.20.tgz && \
    cd Python-3.8.20 && \
    ./configure --enable-optimizations && \
    make altinstall && \
    cd .. && \
    rm -rf Python-3.8.20 Python-3.8.20.tgz

FROM public.ecr.aws/amazonlinux/amazonlinux:2023

COPY --from=build /opt/hhsuite/bin /usr/bin
COPY --from=build /usr/local/bin /usr/bin
COPY --from=build /usr/local/lib /usr/local/lib
COPY alphafold /app/alphafold
COPY hhsearch.py hmmsearch.py /app/alphafold/alphafold/data/tools/
COPY stereo_chemical_props.txt /app/alphafold/alphafold/common/
COPY create_msa_monomer.py search_templates.py generate_features.py new_pipelines.py update_locations.py filter_pdb.py merge_rankings.py /opt/

# Original alphafold-data Dockerfile

# Install python and other dependencies
RUN yum upgrade -y \
  && yum install -y \
  python3 python3-devel \
  unzip \
  gzip \
  tar \
  libgomp \
  gcc \
  procps \
  && yum clean all \
  && rm -rf /var/cache/yum
RUN python3 -m venv /opt/venv39-afdata \
  && source /opt/venv39-afdata/bin/activate \
  && pip install -q --no-cache-dir \
  absl-py==1.4.0 \
  biopython==1.81 \
  dm-tree==0.1.8\
  numpy==1.23.5 \
  pandas==2.0.0 \
  scipy==1.10.1 \
  && pip install --no-cache-dir --no-deps /app/alphafold

# ENV PATH="/opt/venv39-afdata/bin:$PATH"

# Migrated from assets/containers/protein-utils/Dockerfile
COPY putils /tmp/putils

# Install python and other dependencies
RUN python3.8 -m venv /opt/venv38-putils \
  && source /opt/venv38-putils/bin/activate \
  && pip install -q --no-cache-dir \
  pandas==2.0.0 \
  numpy==1.24.2 \
  biopython==1.81 \
  /tmp/putils \
  && yum clean all \
  && rm -rf /var/cache/yum \
  && rm -rf /tmp/putils

# ENV PATH="/opt/venv38-putils/bin:$PATH"


# amazonlinux port of assets/containers/alphafold-predict/Dockerfile, originally Ubuntu
RUN yum install jq awscli wget which git patch -y \
  && yum clean all \
  && rm -rf /var/cache/yum

# Install CUDA toolkit 11.6
RUN wget https://developer.download.nvidia.com/compute/cuda/11.6.0/local_installers/cuda_11.6.0_510.39.01_linux.run
RUN sh cuda_11.6.0_510.39.01_linux.run --silent --toolkit

# Install Miniconda package manager.
RUN wget -q -P /tmp \
    https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh \ 
  && bash /tmp/Miniforge3-Linux-x86_64.sh -b -p /opt/conda \
  && rm /tmp/Miniforge3-Linux-x86_64.sh

# Set environment to auto-accept TOS and use conda-forge
ENV PATH="/opt/conda/bin:$PATH"
ENV LD_LIBRARY_PATH="/opt/conda/lib:$LD_LIBRARY_PATH"
ENV CONDA_PLUGINS_AUTO_ACCEPT_TOS="yes"

RUN /opt/conda/bin/conda install -y -c conda-forge \
  openmm=7.5.1 \
  cudatoolkit=11.6.0 \
  pdbfixer=1.7 \
  pip \
  python=3.9.16 \
  && /opt/conda/bin/conda clean --all --force-pkgs-dirs --yes

ARG ALPHAFOLD2_VERSION=v2.3.2
RUN git clone --branch ${ALPHAFOLD2_VERSION} --depth 1 https://github.com/deepmind/alphafold.git /app/alphafold${ALPHAFOLD2_VERSION}

RUN wget -q -P /app/alphafold${ALPHAFOLD2_VERSION}/alphafold/common/ \
    https://git.scicore.unibas.ch/schwede/openstructure/-/raw/7102c63615b64735c4941278d92b554ec94415f8/modules/mol/alg/src/stereo_chemical_props.txt

# Install pip packages.
RUN /opt/conda/bin/pip3 install --upgrade pip --no-cache-dir \
  && /opt/conda/bin/pip3 install -r /app/alphafold${ALPHAFOLD2_VERSION}/requirements.txt --no-cache-dir \
  && /opt/conda/bin/pip3 install --upgrade --no-cache-dir \
    jax==0.3.25 \
    jaxlib==0.3.25+cuda11.cudnn805 \
    -f https://storage.googleapis.com/jax-releases/jax_cuda_releases.html

RUN /opt/conda/bin/pip3 install --upgrade --no-cache-dir \
  matplotlib==3.6.3 \
  numpy==1.24.3

# Apply OpenMM patch.
WORKDIR /opt/conda/lib/python3.9/site-packages
RUN patch -p0 < /app/alphafold${ALPHAFOLD2_VERSION}/docker/openmm.patch

# # Add SETUID bit to the ldconfig binary so that non-root users can run it.
# RUN chmod u+s /sbin/ldconfig.real

WORKDIR /app/alphafold${ALPHAFOLD2_VERSION}
COPY predict.py /app/alphafold${ALPHAFOLD2_VERSION}/

COPY examples /home/examples

ENTRYPOINT ["bash"]

# Dockerfile info:
# 
# This file is a combination of three Dockerfiles from the original alphafold implementation.
# The first part of the file is from the alphafold-data Dockerfile.
# The second part is from the protein-utils Dockerfile.
# The third part is from the alphafold-predict Dockerfile, with modifications to work on Amazon Linux vs Ubuntu.
# 
# Multiple Python versions are installed in the container to support the different portions of the pipeline
# and their known working pinned dependency versions.

# Python versions installed:
# 3.8.20 - compiled from source, used for label 'protutils' (venv: /opt/venv38-putils)
# 3.9.16 - installed via Miniconda, used for lablel 'predict' (venv: /opt/conda)
# 3.9.? - installed via yum, used for label 'data' (venv: /opt/venv39-afdata)


# New Python environment locations:
# label 'data':      /opt/venv39-afdata
# label 'protutils': /opt/venv38-putils
# label 'predict':   /app/alphafold${ALPHAFOLD2_VERSION}
