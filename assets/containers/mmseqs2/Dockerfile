FROM nvcr.io/nvidia/cuda:12.6.3-base-amzn2023 as base

WORKDIR /home

RUN dnf update -y \
    && dnf install -y tar \
    && dnf clean all \
    && rm -rf /var/cache/dnf/*

RUN curl -O https://mmseqs.com/latest/mmseqs-linux-gpu.tar.gz \
    && tar xzvf mmseqs-linux-gpu.tar.gz \
    && cp /home/mmseqs/bin/mmseqs /usr/local/bin/mmseqs \
    && rm -rf /home/mmseqs \
    && rm mmseqs-linux-gpu.tar.gz 

ENTRYPOINT []