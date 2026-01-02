FROM nvcr.io/nvidia/cuda:12.9.0-runtime-amzn2023 as base

ARG PYTHON='python3.12'
WORKDIR /home

RUN dnf update -y \
    && dnf install -y $PYTHON \
    && dnf clean all \
    && rm -rf /var/cache/dnf/*

ENV VIRTUAL_ENV='/opt/venv'
ENV PATH="${VIRTUAL_ENV}/bin:$PATH"
ENV UV_COMPILE_BYTECODE=1
ENV UV_NO_CACHE=1
ENV UV_PYTHON_DOWNLOADS='never'
ENV UV_PYTHON=$PYTHON

COPY requirements.txt .

RUN dnf install -y tar gzip gcc ${PYTHON}-devel \
    && curl -LsSf https://astral.sh/uv/install.sh | sh \
    && /root/.local/bin/uv venv $VIRTUAL_ENV \
    && /root/.local/bin/uv pip install --no-cache-dir -r requirements.txt

COPY examples /home/examples

ENTRYPOINT []
