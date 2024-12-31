# https://gitlab.com/nvidia/container-images/cuda/-/tree/master/dist/12.6.3/amzn2023
FROM nvcr.io/nvidia/cuda:12.6.3-runtime-amzn2023 as base

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

COPY requirements.txt requirements.txt

RUN dnf install -y tar gzip gcc ${PYTHON}-devel \
    && curl -LsSf https://astral.sh/uv/install.sh | sh \
    && /root/.local/bin/uv venv $VIRTUAL_ENV \
    && /root/.local/bin/uv pip install --no-cache-dir -r requirements.txt

###############################################################################
FROM base as runtime

COPY --from=build $VIRTUAL_ENV $VIRTUAL_ENV

ENTRYPOINT []