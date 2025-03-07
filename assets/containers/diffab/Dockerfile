FROM public.ecr.aws/ubuntu/ubuntu:20.04

# Update package lists and install required packages
RUN apt-get update && apt-get install -y \
    curl \
    git \
    wget \
    unzip \
    tree \
    && rm -rf /var/lib/apt/lists/*

# Install yq for YAML config overrides
RUN wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq && \
    chmod +x /usr/bin/yq

# Install Miniconda and Python 3.8
# https://repo.anaconda.com/miniconda/
ENV MINICONDA_VERSION=Miniconda3-py38_23.11.0-2-Linux-x86_64
RUN curl -O https://repo.anaconda.com/miniconda/$MINICONDA_VERSION.sh \
    && bash $MINICONDA_VERSION.sh -f -b -p /opt/miniconda \
    && rm $MINICONDA_VERSION.sh

# Set up environment variables
ENV PATH=/opt/miniconda/bin:$PATH
ENV PYTHONPATH=/opt/miniconda/lib/python3.8/site-packages:$PYTHONPATH

WORKDIR /opt

# Install diffab
RUN git clone https://github.com/luost26/diffab.git

WORKDIR /opt/diffab

# c3e2966601bf8025025ab87717b31b08fdd4834e = master on 2/3/25
RUN git checkout c3e2966601bf8025025ab87717b31b08fdd4834e

RUN conda config --add channels https://conda.rosettacommons.org && \
    conda config --add channels conda-forge && \
    conda env create -f env.yaml -n diffab

# Set default environment
ENV PATH=/opt/miniconda/envs/diffab/bin:$PATH

RUN conda install -y pyrosetta=2024.04

RUN pip install -U ray==2.10.0

# Copy the configuration generation script, parameterizes the yaml configuration file
COPY generate_config.py /opt/generate_config.py

CMD ["/bin/bash"]
