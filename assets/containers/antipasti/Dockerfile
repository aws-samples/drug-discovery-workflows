FROM public.ecr.aws/ubuntu/ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

ARG MINICONDA_VERSION=Miniconda3-py311_25.1.1-2-Linux-x86_64
ARG PYTHON_VERSION=3.11
ARG ANTIPASTI_VERSION=a8dc208ee4e33cdba707cbe0c9580f92a9668611

# Update package lists and install required packages
RUN apt-get update && apt-get install -y \
    curl \
    git \
    wget \
    littler \
    tree \
    r-base \
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

# Install ANTIPASTI
RUN git clone https://github.com/kevinmicha/ANTIPASTI.git

WORKDIR /opt/ANTIPASTI

RUN git checkout ${ANTIPASTI_VERSION}

RUN conda env create -f antipasti-env.yml

ENV PATH=/opt/miniconda/envs/antipasti-env/bin:$PATH

# Install R packages
RUN /usr/bin/Rscript -e 'install.packages("bio3d")'
RUN /usr/bin/Rscript -e 'install.packages("reticulate")'
RUN /usr/bin/Rscript -e 'install.packages("stringr")'

ENV RETICULATE_PYTHON=/opt/miniconda/envs/antipasti-env/bin/python
ENV UV_OFFLINE=1

COPY predict.py /opt/predict.py
COPY preprocessing.py /opt/ANTIPASTI/antipasti/preprocessing/preprocessing.py

RUN pip install .

RUN ln -s /usr/bin/Rscript /usr/local/bin/RScript

CMD ["/bin/bash"]
