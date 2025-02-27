FROM nvcr.io/nvidia/cuda:12.6.3-runtime-amzn2023 as base

ARG PYTHON='python3.12'
WORKDIR /home

RUN dnf update -y \
    && dnf install -y tar gzip $PYTHON \
    && dnf clean all \
    && rm -rf /var/cache/dnf/*

ENV VIRTUAL_ENV='/opt/venv'
ENV PATH="${VIRTUAL_ENV}/bin:$PATH"

##############################################################################
FROM base as build

ARG PYTHON

COPY requirements.txt .

ENV UV_COMPILE_BYTECODE=1
ENV UV_NO_CACHE=1
ENV UV_PYTHON_DOWNLOADS='never'
ENV UV_PYTHON=$PYTHON

RUN dnf install -y cmake ${PYTHON}-devel \
    && dnf groupinstall -y "Development Tools"

RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && /root/.local/bin/uv venv $VIRTUAL_ENV \
    && /root/.local/bin/uv pip install --no-cache-dir -U -r requirements.txt

# Compile kalign2 from source
RUN pushd /tmp && \
    curl -o kalign.tar.gz https://github.com/TimoLassmann/kalign/archive/refs/tags/v3.4.0.tar.gz -kL \
    && tar -xvzf kalign.tar.gz -C /tmp \
    && mkdir -p /tmp/kalign-3.4.0/build \
    && pushd /tmp/kalign-3.4.0/build \
    && cmake .. \
    && make && make install \
    && popd \
    && rm -rf /tmp/kalign2 && \
    popd

###############################################################################
FROM base as runtime

COPY --from=build $VIRTUAL_ENV $VIRTUAL_ENV
COPY --from=build /usr/local/bin/kalign /usr/local/bin/kalign
ENV PATH="$PATH:/$VIRTUAL_ENV"
COPY scripts/ /home/scripts/
COPY rcsb.py $VIRTUAL_ENV/lib/python3.11/site-packages/chai_lab/data/io/
WORKDIR /home/scripts

# https://pytorch.org/docs/stable/notes/cuda.html#environment-variables
ENV PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

ENTRYPOINT []