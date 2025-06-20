# Tagged version 2.1.0
# https://github.com/aqlaboratory/openfold/blob/v.2.1.0/Dockerfile

# Modifications have been made to work within the aws-samples/drug-discovery-workflows repository
# Mostly addition of git clone and comment out COPY statements 

#FROM nvidia/cuda:11.3.1-cudnn8-devel-ubuntu18.04
FROM nvcr.io/nvidia/cuda:11.3.1-cudnn8-devel-ubuntu18.04

# metainformation
LABEL org.opencontainers.image.version = "1.0.0"
LABEL org.opencontainers.image.authors = "Gustaf Ahdritz"
LABEL org.opencontainers.image.source = "https://github.com/aqlaboratory/openfold"
LABEL org.opencontainers.image.licenses = "Apache License 2.0"
LABEL org.opencontainers.image.base.name="docker.io/nvidia/cuda:10.2-cudnn8-runtime-ubuntu18.04"

RUN apt-key del 7fa2af80
RUN apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/7fa2af80.pub
RUN apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/3bf863cc.pub

RUN apt-get update && apt-get install -y wget libxml2 cuda-minimal-build-11-3 libcusparse-dev-11-3 libcublas-dev-11-3 libcusolver-dev-11-3 git tree gzip
RUN wget -P /tmp \
    "https://github.com/conda-forge/miniforge/releases/download/23.3.1-1/Miniforge3-Linux-x86_64.sh" \
    && bash /tmp/Miniforge3-Linux-x86_64.sh -b -p /opt/conda \
    && rm /tmp/Miniforge3-Linux-x86_64.sh
ENV PATH /opt/conda/bin:$PATH

# Tagged version 2.1.0
RUN mkdir -p /opt/openfold
RUN git clone https://github.com/aqlaboratory/openfold.git /opt/openfold && cd /opt/openfold && git checkout f434a2786b5a6b39171f358fb3470ad9f4fd2a58

WORKDIR /opt/openfold

# The git clone does this already
# COPY environment.yml /opt/openfold/environment.yml

# installing into the base environment since the docker container wont do anything other than run openfold
RUN mamba env update -n base --file /opt/openfold/environment.yml && mamba clean --all
RUN export LD_LIBRARY_PATH=${CONDA_PREFIX}/lib:${LD_LIBRARY_PATH}

# The git clone does this already
# COPY openfold /opt/openfold/openfold
# COPY scripts /opt/openfold/scripts
# COPY run_pretrained_openfold.py /opt/openfold/run_pretrained_openfold.py
# COPY train_openfold.py /opt/openfold/train_openfold.py
# COPY setup.py /opt/openfold/setup.py

COPY ./prep_mmseqs_dbs.mod.sh /opt/openfold/scripts/prep_mmseqs_dbs.sh

RUN ./scripts/install_third_party_dependencies.sh

# from scripts/install_third_party_dependencies.sh
# RUN wget -q -P /opt/openfold/openfold/resources \
#     https://git.scicore.unibas.ch/schwede/openstructure/-/raw/7102c63615b64735c4941278d92b554ec94415f8/modules/mol/alg/src/stereo_chemical_props.txt
# WORKDIR /opt/openfold
# RUN python3 setup.py install
