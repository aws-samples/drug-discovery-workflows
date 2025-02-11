FROM nvcr.io/nvidia/cuda:12.6.3-base-amzn2023 as base

ARG PYTHON='python3.11'
WORKDIR /home

RUN dnf update -y \
    && dnf install -y $PYTHON \
    && dnf clean all \
    && rm -rf /var/cache/dnf/*

ENV VIRTUAL_ENV='/opt/venv'
ENV PATH="${VIRTUAL_ENV}/bin:$PATH"

##############################################################################
FROM base as build

ARG PYTHON

ENV UV_COMPILE_BYTECODE=1
ENV UV_NO_CACHE=1
ENV UV_PYTHON_DOWNLOADS='never'
ENV UV_PYTHON=$PYTHON

COPY requirements.txt .

RUN dnf install -y tar gzip gcc ${PYTHON}-devel \
    && curl -LsSf https://astral.sh/uv/install.sh | sh \
    && /root/.local/bin/uv venv $VIRTUAL_ENV \
    && /root/.local/bin/uv pip install --no-cache-dir -r requirements.txt

RUN curl -O https://mmseqs.com/latest/mmseqs-linux-gpu.tar.gz \
    && tar xzvf mmseqs-linux-gpu.tar.gz \
    && rm mmseqs-linux-gpu.tar.gz 

###############################################################################
FROM base as runtime

COPY --from=build $VIRTUAL_ENV $VIRTUAL_ENV
COPY --from=build /home/mmseqs/bin/mmseqs /usr/local/bin/mmseqs
COPY setup_msa_databases.sh .
COPY colabfold_search.py .
COPY msa.sh .

ENTRYPOINT []