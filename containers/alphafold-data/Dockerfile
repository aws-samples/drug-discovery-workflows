# Copyright 2023 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

FROM public.ecr.aws/amazonlinux/amazonlinux:latest as build

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
  && yum clean all \
  && rm -rf /var/cache/yum

# ADD hh-suite.tar.gz /tmp/hh-suite
# RUN pushd /tmp/hh-suite \
#   && cmake -DCMAKE_INSTALL_PREFIX=/opt/hhsuite . \
#   && make && make install \
#   && popd
RUN pushd /tmp && \
git clone https://github.com/soedinglab/hh-suite.git && \
cd hh-suite && mkdir build && cd build && \
cmake -DCMAKE_INSTALL_PREFIX=/opt/hhsuite .. && \
make -j 4 && make install && \
popd

# ADD kalign.tar.gz /tmp/kalign-3.4.3
# RUN pushd /tmp/kalign2 \
#   && ./configure \
#   && make && make install \
#   && popd
# RUN pushd /tmp && \
# wget https://github.com/TimoLassmann/kalign/archive/refs/tags/v3.4.0.tar.gz && \
# tar -xvzf v3.4.0.tar.gz && \
# cd kalign-3.4.0 && \
# mkdir build && \
# cd build && \
# cmake3 .. && \
# make -j 4 && make test && \
# make install && \
# popd

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

FROM public.ecr.aws/amazonlinux/amazonlinux:latest

COPY --from=build /opt/hhsuite/bin /usr/bin
COPY --from=build /usr/local/bin /usr/bin
COPY alphafold /app/alphafold
COPY hhsearch.py hmmsearch.py /app/alphafold/alphafold/data/tools/
COPY stereo_chemical_props.txt /app/alphafold/alphafold/common/
COPY create_msa_monomer.py search_templates.py generate_features.py new_pipelines.py update_locations.py filter_pdb.py merge_rankings.py /opt/

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
RUN python3 -m venv /opt/venv \
  && source /opt/venv/bin/activate \
  && pip install -q --no-cache-dir \
  absl-py==1.4.0 \
  biopython==1.81 \
  dm-tree==0.1.8\
  numpy==1.23.5 \
  pandas==2.0.0 \
  scipy==1.10.1 \
  && pip install --no-cache-dir --no-deps /app/alphafold

ENV VIRTUAL_ENV="/opt/venv"
ENV PATH="$VIRTUAL_ENV/bin:$PATH"


WORKDIR /home
