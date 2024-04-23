# Based off https://github.com/aws/deep-learning-containers/blob/master/pytorch/inference/docker/2.1/py3/cu118/Dockerfile.gpu

ARG PYTHON=python3
ARG PYTHON_VERSION=3.10.9
ARG MAMBA_VERSION=22.11.1-4
ARG OPEN_MPI_VERSION=4.1.5

# Nvidia software versions
ARG CUBLAS_VERSION=11.11.3.6
ARG CUDNN_VERSION=8.8.0.121
ARG NCCL_VERSION=2.16.5
ARG NVML_VERSION=11.8.86

# PyTorch Binaries and versions.
ARG TORCH_URL=https://framework-binaries.s3.us-west-2.amazonaws.com/pytorch/v2.1.0/cuda11.8.0/torch-2.1.0%2Bcu118-cp310-cp310-linux_x86_64.whl
ARG TORCHVISION_URL=https://framework-binaries.s3.us-west-2.amazonaws.com/pytorch/v2.1.0/cuda11.8.0/torchvision-0.16.0%2Bcu118-cp310-cp310-linux_x86_64.whl
ARG TORCHAUDIO_URL=https://framework-binaries.s3.us-west-2.amazonaws.com/pytorch/v2.1.0/cuda11.8.0/torchaudio-2.1.0%2Bcu118-cp310-cp310-linux_x86_64.whl
ARG TORCHTEXT_URL=https://framework-binaries.s3.us-west-2.amazonaws.com/pytorch/v2.1.0/cuda11.8.0/torchtext-0.16.0%2Bcu118-cp310-cp310-linux_x86_64.whl
ARG TORCHDATA_URL=https://framework-binaries.s3.us-west-2.amazonaws.com/pytorch/v2.1.0/cuda11.8.0/torchdata-0.7.0%2B7c7597b-cp310-cp310-linux_x86_64.whl

########################################################
#  _____ ____ ____    ___
# | ____/ ___|___ \  |_ _|_ __ ___   __ _  __ _  ___
# |  _|| |     __) |  | || '_ ` _ \ / _` |/ _` |/ _ \
# | |__| |___ / __/   | || | | | | | (_| | (_| |  __/
# |_____\____|_____| |___|_| |_| |_|\__,_|\__, |\___|
#                                         |___/
#  ____           _
# |  _ \ ___  ___(_)_ __   ___ 
# | |_) / _ \/ __| | '_ \ / _ \
# |  _ <  __/ (__| | |_) |  __/
# |_| \_\___|\___|_| .__/ \___|
#                  |_|
########################################################

# FROM nvidia/cuda:11.8.0-base-ubuntu20.04 AS ec2
FROM nvcr.io/nvidia/cuda:11.8.0-base-ubuntu20.04

LABEL maintainer="Amazon AI"
LABEL dlc_major_version="1"

ARG PYTHON
ARG PYTHON_VERSION
ARG MAMBA_VERSION
ARG OPEN_MPI_VERSION

# PyTorch Passed arguments (URLs and Versions)
ARG TORCH_URL
ARG TORCHVISION_URL
ARG TORCHAUDIO_URL
ARG TORCHTEXT_URL
ARG TORCHDATA_URL
# ARG TORCHSERVE_VERSION

# Nvidia passed Arguments
ARG CUBLAS_VERSION
ARG CUDNN_VERSION
ARG NVML_VERSION
ARG NCCL_VERSION

# Set Env Variables for the images
ENV DEBIAN_FRONTEND=noninteractive \
    LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/usr/local/lib" \
    LD_LIBRARY_PATH="/opt/conda/lib:${LD_LIBRARY_PATH}" \
    PATH=/opt/conda/bin:$PATH \
    TEMP=/home/model-server/tmp \
    # Set MKL_THREADING_LAYER=GNU to prevent issues between torch and numpy/mkl
    MKL_THREADING_LAYER=GNU \
    DLC_CONTAINER_TYPE=inference \
    # See http://bugs.python.org/issue19846
    LANG=C.UTF-8

## Cuda Arch List setting Options
# Kepler+Tesla = 3.7 (P2 Instances "No Longer Supported")
# Kepler = 3.5+PTX
# Maxwell+Tegra = 5.3
# Maxwell = 5.0;5.2+PTX (G3 Instances)
# Pascal = 6.0;6.1+PTX
# Volta = 7.0+PTX (P3 Instances)
# Turing = 7.5+PTX (G4 Instances)
# Ampere = 8.0;8.6+PTX (P4 and G5 Instances)
# Ada = 8.9+PTX
ENV TORCH_CUDA_ARCH_LIST="7.5+PTX 8.6+PTX"
ENV NVCC_GENCODE="-gencode=arch=compute_75,code=sm_75 -gencode=arch=compute_86,code=sm_86"


RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get install -y --allow-downgrades --allow-change-held-packages --no-install-recommends \
    build-essential \
    ca-certificates \
    cmake \
    libcurl4-openssl-dev \
    cuda-cudart-11-8 \
    cuda-libraries-11-8 \
    cuda-libraries-dev-11-8 \
    cuda-command-line-tools-11-8 \
    cuda-nvcc-11-8 \
    libcublas-11-8=${CUBLAS_VERSION}-1 \
    libcublas-dev-11-8=${CUBLAS_VERSION}-1 \
    cuda-nvml-dev-11-8=${NVML_VERSION}-1 \
    libcudnn8=${CUDNN_VERSION}-1+cuda11.8 \
    curl \
    emacs \
    git \
    jq \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libgomp1 \
    libibverbs-dev \
    libnuma1 \
    libnuma-dev \
    libsm6 \
    libssl1.1 \
    libssl-dev \
    libxext6 \
    libxrender-dev \
    openjdk-17-jdk \
    openssl \
    vim \
    wget \
    unzip \
    libjpeg-dev \
    libpng-dev \
    zlib1g-dev \
    openssh-client \
    openssh-server \
    nano \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Install NCCL
RUN cd /tmp \
    && git clone https://github.com/NVIDIA/nccl.git -b v${NCCL_VERSION}-1 \
    && cd nccl \
    && make -j64 src.build BUILDDIR=/usr/local NVCC_GENCODE="$NVCC_GENCODE" \
    && rm -rf /tmp/nccl

# Install OpenMPI
RUN wget --quiet https://download.open-mpi.org/release/open-mpi/v4.1/openmpi-${OPEN_MPI_VERSION}.tar.gz \
    && gunzip -c openmpi-${OPEN_MPI_VERSION}.tar.gz | tar xf - \
    && cd openmpi-${OPEN_MPI_VERSION} \
    && ./configure --prefix=/home/.openmpi --with-cuda \
    && make all install \
    && cd .. \
    && rm openmpi-${OPEN_MPI_VERSION}.tar.gz \
    && rm -rf openmpi-${OPEN_MPI_VERSION}

# The ENV variables declared below are changed in the previous section
# Grouping these ENV variables in the first section causes
# ompi_info to fail. This is only observed in CPU containers
ENV PATH="$PATH:/home/.openmpi/bin"
ENV LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/home/.openmpi/lib/"
RUN ompi_info --parsable --all | grep mpi_built_with_cuda_support:value

# Install CondaForge miniconda
RUN curl -L -o ~/mambaforge.sh https://github.com/conda-forge/miniforge/releases/download/${MAMBA_VERSION}/Mambaforge-${MAMBA_VERSION}-Linux-x86_64.sh \
    && chmod +x ~/mambaforge.sh \
    && ~/mambaforge.sh -b -p /opt/conda \
    && rm ~/mambaforge.sh \
    && /opt/conda/bin/conda install -c conda-forge python=${PYTHON_VERSION} \
    cython \
    mkl-include \
    parso \
    scipy \
    typing \
    h5py \
    requests \
    libgcc \
    # Below 2 are included in miniconda base, but not mamba so need to install
    conda-content-trust \
    charset-normalizer \
    && /opt/conda/bin/conda install -c pytorch magma-cuda118 \
    && /opt/conda/bin/conda clean -ya

# symlink pip for OS use
RUN pip install --upgrade pip --trusted-host pypi.org --trusted-host files.pythonhosted.org \
    && ln -s /opt/conda/bin/pip /usr/local/bin/pip3

# Install Common python packages
RUN pip install --no-cache-dir -U \
    boto3 \
    opencv-python \
    nvgpu \
    pyOpenSSL \
    cryptography \
    "ipython>=8.10.0,<9.0" \
    "urllib3>=1.26.18,<2" \
    "mkl>=2023.2.0,<2024.1"

# Ensure PyTorch did not get installed from Conda or pip, prior to now
# Any Nvidia installs for the DLC will be below, removing nvidia and cuda packages from pip here
# Even the GPU image would not have nvidia or cuda packages in PIP.
RUN pip uninstall -y torch torchvision torchaudio torchdata model-archiver multi-model-server

# install pytorch wheels
RUN pip install --no-cache-dir -U \
    # triton required for torch inductor
    triton \
    ${TORCH_URL} \
    ${TORCHVISION_URL} \
    ${TORCHAUDIO_URL} \
    ${TORCHTEXT_URL} \
    ${TORCHDATA_URL}

# add necessary certificate for aws sdk cpp download
RUN mkdir -p /etc/pki/tls/certs && cp /etc/ssl/certs/ca-certificates.crt /etc/pki/tls/certs/ca-bundle.crt

RUN curl -o /license.txt  https://aws-dlc-licenses.s3.amazonaws.com/pytorch-2.1/license.txt

# Install additional dependencies from requirements.txt file
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -U -r /tmp/requirements.txt \
    && rm /tmp/requirements.txt

## Cleanup ##
RUN pip cache purge \
    && rm -rf /tmp/tmp* \
    && rm -iRf /root/.cache

COPY scripts/ /home/scripts/
WORKDIR /home/scripts

ENTRYPOINT [ "python" ]