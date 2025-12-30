FROM public.ecr.aws/ubuntu/ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

ARG MINICONDA_VERSION=Miniconda3-latest-Linux-x86_64
ARG PYTHON_VERSION=3.10
ARG CONDA_PYTHON_VERSION=3.10.8
ARG DEEPSTABP_VERSION=da616fff398a3fd077d0ba64cd69c9de60531bb0
ARG PIP_VERSION=24.0

# Update package lists and install required packages
RUN apt-get update && apt-get install -y \
    curl \
    git \
    wget \
    unzip \
    tree \
    build-essential \
    && rm -rf /var/lib/apt/lists/*


# Install Miniforge (conda-forge by default)
# https://github.com/conda-forge/miniforge
RUN wget -q -P /tmp \
    https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh \
    && bash /tmp/Miniforge3-Linux-x86_64.sh -f -b -p /opt/miniconda \
    && rm /tmp/Miniforge3-Linux-x86_64.sh

# Set up environment variables
ENV PATH=/opt/miniconda/bin:$PATH
ENV PYTHONPATH=/opt/miniconda/lib/python${PYTHON_VERSION}/site-packages:$PYTHONPATH
ENV CONDA_PLUGINS_AUTO_ACCEPT_TOS="yes"

WORKDIR /opt

# Install 
RUN git clone https://git.nfdi4plants.org/f_jung/deepstabp.git

WORKDIR /opt/deepstabp

RUN git checkout ${DEEPSTABP_VERSION}

RUN conda config --add channels conda-forge && \
    conda config --set channel_priority strict && \
    conda create -n "deepstabp" python=${CONDA_PYTHON_VERSION} -y

# Set default environment
ENV PATH=/opt/miniconda/envs/deepstabp/bin:$PATH

RUN pip install pip==${PIP_VERSION}

COPY requirements.txt /opt/deepstabp/requirements.txt

RUN pip install -r requirements.txt

CMD ["/bin/bash"]
