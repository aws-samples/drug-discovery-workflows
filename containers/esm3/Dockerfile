############################################################################
FROM public.ecr.aws/amazonlinux/amazonlinux:2023 as al2023-cuda-runtime
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# Based on https://gitlab.com/nvidia/container-images/cuda/-/blob/master/dist/12.1.1/ubi9
# cuda-base
ENV NVARCH x86_64
ENV NVIDIA_REQUIRE_CUDA "cuda>=12.1 brand=tesla,driver>=470,driver<471 brand=unknown,driver>=470,driver<471 brand=nvidia,driver>=470,driver<471 brand=nvidiartx,driver>=470,driver<471 brand=geforce,driver>=470,driver<471 brand=geforcertx,driver>=470,driver<471 brand=quadro,driver>=470,driver<471 brand=quadrortx,driver>=470,driver<471 brand=titan,driver>=470,driver<471 brand=titanrtx,driver>=470,driver<471 brand=tesla,driver>=525,driver<526 brand=unknown,driver>=525,driver<526 brand=nvidia,driver>=525,driver<526 brand=nvidiartx,driver>=525,driver<526 brand=geforce,driver>=525,driver<526 brand=geforcertx,driver>=525,driver<526 brand=quadro,driver>=525,driver<526 brand=quadrortx,driver>=525,driver<526 brand=titan,driver>=525,driver<526 brand=titanrtx,driver>=525,driver<526"
ENV NV_CUDA_CUDART_VERSION 12.1.105-1
ENV CUDA_VERSION 12.1.1
ENV PATH /usr/local/nvidia/bin:/usr/local/cuda/bin:${PATH}
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility
# cuda-runtime
ENV NV_CUDA_LIB_VERSION 12.1.1-1
ENV NV_NVTX_VERSION 12.1.105-1
ENV NV_LIBNPP_VERSION 12.1.0.40-1
ENV NV_LIBNPP_PACKAGE libnpp-12-1-${NV_LIBNPP_VERSION}
ENV NV_LIBCUBLAS_VERSION 12.1.3.1-1
ENV NV_LIBNCCL_PACKAGE_NAME libnccl
ENV NV_LIBNCCL_PACKAGE_VERSION 2.17.1-1
ENV NV_LIBNCCL_VERSION 2.17.1
ENV NCCL_VERSION 2.17.1
ENV NV_LIBNCCL_PACKAGE ${NV_LIBNCCL_PACKAGE_NAME}-${NV_LIBNCCL_PACKAGE_VERSION}+cuda12.1
# cuda-runtime-cudnn8
ENV NV_CUDNN_VERSION 8.9.0.131-1
ENV NV_CUDNN_PACKAGE libcudnn8-${NV_CUDNN_VERSION}.cuda12.1

COPY cuda.repo-x86_64 /etc/yum.repos.d/cuda.repo
COPY NGC-DL-CONTAINER-LICENSE /

RUN NVIDIA_GPGKEY_SUM=d0664fbbdb8c32356d45de36c5984617217b2d0bef41b93ccecd326ba3b80c87 && \
    curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/rhel9/${NVARCH}/D42D0685.pub | sed '/^Version/d' > /etc/pki/rpm-gpg/RPM-GPG-KEY-NVIDIA && \
    echo "$NVIDIA_GPGKEY_SUM  /etc/pki/rpm-gpg/RPM-GPG-KEY-NVIDIA" | sha256sum -c --strict - \
    && yum update -y && yum install -y \
    # cuda-base
    cuda-cudart-12-1-${NV_CUDA_CUDART_VERSION} \
    cuda-compat-12-1 \
    # cuda-runtime
    cuda-libraries-12-1-${NV_CUDA_LIB_VERSION} \
    cuda-nvtx-12-1-${NV_NVTX_VERSION} \
    ${NV_LIBNPP_PACKAGE} \
    libcublas-12-1-${NV_LIBCUBLAS_VERSION} \
    ${NV_LIBNCCL_PACKAGE} \
    # cuda-runtime-cudnn8
    ${NV_CUDNN_PACKAGE} #gitleaks:allow


############################################################################
FROM al2023-cuda-runtime as al2023-cuda-dev
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV NV_NVPROF_VERSION 12.1.105-1
ENV NV_NVPROF_DEV_PACKAGE cuda-nvprof-12-1-${NV_NVPROF_VERSION}
ENV NV_CUDA_CUDART_DEV_VERSION 12.1.105-1
ENV NV_NVML_DEV_VERSION 12.1.105-1
ENV NV_LIBCUBLAS_DEV_VERSION 12.1.3.1-1
ENV NV_LIBNPP_DEV_VERSION 12.1.0.40-1
ENV NV_LIBNPP_DEV_PACKAGE libnpp-devel-12-1-${NV_LIBNPP_DEV_VERSION}
ENV NV_LIBNCCL_DEV_PACKAGE_NAME libnccl-devel
ENV NV_LIBNCCL_DEV_PACKAGE_VERSION 2.17.1-1
ENV NV_LIBNCCL_DEV_PACKAGE ${NV_LIBNCCL_DEV_PACKAGE_NAME}-${NV_LIBNCCL_DEV_PACKAGE_VERSION}+cuda12.1
ENV NV_CUDA_NSIGHT_COMPUTE_VERSION 12.1.1-1
ENV NV_CUDA_NSIGHT_COMPUTE_DEV_PACKAGE cuda-nsight-compute-12-1-${NV_CUDA_NSIGHT_COMPUTE_VERSION}
ENV LIBRARY_PATH /usr/local/cuda/lib64/stubs
ENV NV_CUDNN_PACKAGE_DEV libcudnn8-devel-${NV_CUDNN_VERSION}.cuda12.1

RUN yum update -y && yum install -y \
    "make-1:4.3-5.amzn2023.0.2" \
    "findutils-1:4.8.0-2.amzn2023.0.2" \
    "cuda-command-line-tools-12-1-${NV_CUDA_LIB_VERSION}" \
    "cuda-libraries-devel-12-1-${NV_CUDA_LIB_VERSION}" \
    "cuda-minimal-build-12-1-${NV_CUDA_LIB_VERSION}" \
    "cuda-cudart-devel-12-1-${NV_CUDA_CUDART_DEV_VERSION}" \
    "${NV_NVPROF_DEV_PACKAGE}" \
    "cuda-nvml-devel-12-1-${NV_NVML_DEV_VERSION}" \
    "libcublas-devel-12-1-${NV_LIBCUBLAS_DEV_VERSION}" \
    "${NV_LIBNPP_DEV_PACKAGE}" \
    "${NV_LIBNCCL_DEV_PACKAGE}" \
    "${NV_CUDA_NSIGHT_COMPUTE_DEV_PACKAGE}" \
    "${NV_CUDNN_PACKAGE_DEV}" \
    "tar-2:1.34-1.amzn2023.0.4" \
    "gzip-1.12-1.amzn2023.0.1" \
    "perl-4:5.32.1-477.amzn2023.0.6" \
    && yum clean all \
    && rm -rf /var/cache/yum/*

############################################################################
FROM al2023-cuda-dev as dlc-ec2
# Based on https://github.com/aws/deep-learning-containers/blob/master/pytorch/inference/docker/2.2/py3/cu118/Dockerfile.gpu
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG PYTHON_VERSION=3.10.14
ARG MINIFORGE3_VERSION=24.3.0-0
ARG OPEN_MPI_VERSION=4.1.6
ARG TORCHSERVE_VERSION=0.11.0

# Python won’t try to write .pyc or .pyo files on the import of source modules
# Force stdin, stdout and stderr to be totally unbuffered. Good for logging
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV LD_LIBRARY_PATH "/opt/conda/lib:/usr/local/lib:/usr/local/nvidia/lib:/usr/local/nvidia/lib64:/home/.openmpi/lib/"
ENV PATH="$PATH:/home/.openmpi/bin"
ENV PYTHONIOENCODING=UTF-8
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV PATH=/opt/conda/bin:$PATH
ENV TEMP=/home/model-server/tmp
ENV MKL_THREADING_LAYER=GNU

## Cuda Arch List setting Options
# Turing = 7.5+PTX (G4 Instances)
# Ampere = 8.0;8.6+PTX (P4 and G5 Instances)
# Ada = 8.9+PTX (G6 Instances)
# Hopper = 9.0 (P5 Instances)
ENV TORCH_CUDA_ARCH_LIST="7.5+PTX 8.0 8.6+PTX 8.9+PTX 9.0"
ENV DLC_CONTAINER_TYPE=inference
# makes AllToAll complete successfully. Update will be included in NCCL 2.20.*
ENV NCCL_CUMEM_ENABLE=0
ENV TOKENIZERS_PARALLELISM=true

WORKDIR /

RUN yum update -y && yum install -y \
    ca-certificates \
    git \
    jq \
    nano \
    openssl \
    tar \
    unzip \
    which \
    && yum clean all \
    && rm -rf /var/cache/yum/* \
    # && curl -L -o openmpi-${OPEN_MPI_VERSION}.tar.gz https://download.open-mpi.org/release/open-mpi/v4.1/openmpi-${OPEN_MPI_VERSION}.tar.gz \
    # && gunzip -c openmpi-${OPEN_MPI_VERSION}.tar.gz | tar xf - \
    # && cd openmpi-${OPEN_MPI_VERSION} \
    # && ./configure --prefix=/home/.openmpi --with-cuda \
    # && make all install \
    # && cd .. \
    # && rm openmpi-${OPEN_MPI_VERSION}.tar.gz \
    # && rm -rf openmpi-${OPEN_MPI_VERSION} \
    # && mkdir -p /home/model-server/tmp /opt/ml/model \
    # && ompi_info --parsable --all | grep mpi_built_with_cuda_support:value \
    && curl -L -o ~/miniforge3.sh https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE3_VERSION}/Mambaforge-${MINIFORGE3_VERSION}-Linux-x86_64.sh \
    && chmod +x ~/miniforge3.sh \
    && ~/miniforge3.sh -b -p /opt/conda \
    && rm ~/miniforge3.sh \
    && /opt/conda/bin/mamba install -y -c pytorch -c nvidia -c conda-forge \
    python=${PYTHON_VERSION} \
    # awscli \
    boto3 \
    charset-normalizer \
    cmake \
    conda-content-trust \
    cython \
    h5py \
    libgcc \
    mkl==2024.0 \
    mkl-include \
    numpy \
    packaging \
    pandas \
    parso \
    pyarrow \
    pyyaml \
    requests \
    scipy \
    typing \
    && /opt/conda/bin/mamba clean -afy \
    && rm -rf /etc/apt/sources.list.d/* \
    && pip install --upgrade pip --no-cache-dir --trusted-host pypi.org --trusted-host files.pythonhosted.org \
    && ln -s /opt/conda/bin/pip /usr/local/bin/pip3 \
    && pip uninstall -y torch torchvision torchaudio torchdata model-archiver multi-model-server \
    && pip install --no-cache-dir -U \
    biopython==1.83 \
    biotite==0.40.0 \
    cloudpathlib \
    "cryptography>=42.0.5" \
    einops==0.8.0 \
    msgpack_numpy==0.4.8 \
    nvgpu==0.10.0 \
    opencv-python==4.9.0.80 \
    "prompt-toolkit<3.0.39" \
    "pyopenssl>=24.0.0" \
    scipy==1.13.0 \
    tokenizers==0.19.1\
    torch==2.3.0 \
    torchvision==0.18.0 \
    torchaudio==2.3.0 \
    torchtext==0.18.0 \
    torchdata==0.7.1 \
    transformers==4.41.0 \
    triton==2.3.0 \
    "urllib3>=1.26.18,<2" \
    && pip install --no-cache-dir -U \
    flash-attn \
    git+https://github.com/Dao-AILab/flash-attention.git#subdirectory=csrc/rotary

############################################################################
FROM al2023-cuda-runtime as model-server
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN mkdir -p /home/model-server/tmp /opt/ml/model /home/model-server/output \
    && rm -rf /tmp/tmp* \
    && rm -iRf /root/.cache \
    && yum install -y \
    "gcc-11.4.1-2.amzn2023.0.2" \
    "tar-2:1.34-1.amzn2023.0.4" \
    "gzip-1.12-1.amzn2023.0.1" \
    && yum clean all \
    && rm -rf /var/cache/yum/*

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm awscliv2.zip

COPY --from=dlc-ec2 /opt/conda /opt/conda
# COPY --from=dlc-ec2 /home/.openmpi /home/.openmpi
# This will eventually hold the OSS inference code
COPY esm /home/model-server/esm

# ENV PATH="$PATH:/home/.openmpi/bin"
ENV PATH=/opt/conda/bin:$PATH
# makes AllToAll complete successfully. Update will be included in NCCL 2.20.*
ENV NCCL_CUMEM_ENABLE=0
ENV TOKENIZERS_PARALLELISM=true
WORKDIR /home/model-server

############################################################################
FROM model-server as esm3
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN pip install attrs "scikit-learn==1.4.1.post1" "numpy<2" "esm"
COPY predict_annotations.py /home/model-server/


