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
