FROM ubuntu:20.04

# Update package lists and install required packages
RUN apt-get update && apt-get install -y \
    curl \
    git \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install yq for YAML config overrides
RUN wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq && \
    chmod +x /usr/bin/yq

# Install Miniconda and Python 3.9
# https://repo.anaconda.com/miniconda/
ENV MINICONDA_VERSION=Miniconda3-py39_24.11.1-0-Linux-x86_64
RUN curl -O https://repo.anaconda.com/miniconda/$MINICONDA_VERSION.sh \
    && bash $MINICONDA_VERSION.sh -f -b -p /opt/miniconda \
    && rm $MINICONDA_VERSION.sh

# Set up environment variables
ENV PATH=/opt/miniconda/bin:$PATH
ENV PYTHONPATH=/opt/miniconda/lib/python3.8/site-packages:$PYTHONPATH

WORKDIR /opt

# Install ANARCI
RUN conda install -c conda-forge biopython=1.85 -y \
    && conda install -c bioconda anarci=2024.05.21 hmmer=3.3.2 -y

# Install Humatch
RUN git clone https://github.com/oxpig/Humatch.git

WORKDIR /opt/Humatch

# b43e1aaea86968553b9f322c94193618c91dec1f = master on 1/28/25
RUN git checkout b43e1aaea86968553b9f322c94193618c91dec1f

# Copy pinned versions
COPY humatch.setup.py setup.py

# Download pre-trained models
RUN mkdir -p /opt/Humatch/Humatch/trained_models
WORKDIR /opt/Humatch/Humatch/trained_models
RUN curl -o heavy.weights.h5 https://zenodo.org/records/13764771/files/heavy.weights.h5?download=1 && \
    curl -o light.weights.h5 https://zenodo.org/records/13764771/files/light.weights.h5?download=1 && \
    curl -o paired.weights.h5 https://zenodo.org/records/13764771/files/paired.weights.h5?download=1

# download germline_likeness_lookup_arrays
RUN mkdir -p /opt/Humatch/Humatch/germline_likeness_lookup_arrays
WORKDIR /opt/Humatch/Humatch/germline_likeness_lookup_arrays
# https://github.com/lewis-chinery/Humatch/blob/2724071a1757d6a28748ff191c829c37e07cf93e/Humatch/germline_likeness.py#L11-L65
RUN python3 -c 'import requests; vgenes = [f"hv{i}" for i in range(1, 8)] + [f"lv{i}" for i in range(1, 11)] + [f"kv{i}" for i in range(1, 8)]; [open(f"{gene}.npy", "wb").write(requests.get(f"https://zenodo.org/records/13764771/files/{gene}.npy?download=1").content) for gene in vgenes]'

WORKDIR /opt/Humatch

# Install Humatch + downloaded assets: trained_modelsm, germline_likeness_lookup_arrays
RUN pip install .

# Ensure we've got CUDA GPU support for tensorflow
RUN pip install 'tensorflow[and-cuda]'

# Copy the configuration generation script, parameterizes the yaml configuration file
COPY generate_config.py /opt/generate_config.py

CMD ["/bin/bash"]
