ARG AWS_DEFAULT_REGION=us-east-1

FROM 763104351884.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/huggingface-pytorch-training:1.13.1-transformers4.26.0-gpu-py39-cu117-ubuntu20.04

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
    
# Install additional dependencies following instructions from https://github.com/Genentech/equifold
# RUN pip install pytorch=1.11 cudatoolkit=11.3 -c pytorch -y
RUN pip install pytorch-lightning==2.0 torch==1.13.1 \
    && pip install e3nn biopython pandas tqdm einops \
    && pip install --no-index torch-scatter torch-sparse torch-cluster torch-spline-conv pyg_lib -f https://data.pyg.org/whl/torch-1.13.1%2Bcu117.html \
    && pip install torch_geometric

## Cleanup ##
RUN pip cache purge \
    && rm -rf /tmp/tmp* \
    && rm -iRf /root/.cache

ENV TMPDIR="/tmp"
COPY equifold/ /home/equifold/
WORKDIR /home/equifold

ENTRYPOINT []