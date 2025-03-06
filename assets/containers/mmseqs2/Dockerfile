FROM nvcr.io/nvidia/cuda:12.6.3-base-amzn2023 as base

WORKDIR /home

RUN dnf update -y \
    && dnf install -y $PYTHON tar gzip wget rsync \
    && dnf clean all \
    && rm -rf /var/cache/dnf/*

RUN curl -O https://mmseqs.com/latest/mmseqs-linux-gpu.tar.gz \
    && tar xzvf mmseqs-linux-gpu.tar.gz \
    && rm mmseqs-linux-gpu.tar.gz \
    && mv /home/mmseqs/bin/mmseqs /usr/local/bin/mmseqs

COPY setup_msa_databases.sh msa.sh pair.sh clean_fasta.sh /home/

ENTRYPOINT []