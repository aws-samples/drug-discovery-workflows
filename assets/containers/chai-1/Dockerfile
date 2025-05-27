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
ARG CHAI_VERSION="0.6.1"

COPY requirements.txt .
COPY rcsb.py .

ENV UV_COMPILE_BYTECODE=1
ENV UV_NO_CACHE=1
ENV UV_PYTHON_DOWNLOADS='never'
ENV UV_PYTHON=$PYTHON

RUN dnf install -y cmake ${PYTHON}-devel \
    && dnf groupinstall -y "Development Tools"

RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && /root/.local/bin/uv venv $VIRTUAL_ENV \
    && /root/.local/bin/uv pip install --no-cache-dir -U -r requirements.txt

# Install chai from source 
RUN curl -Lo /tmp/chai.zip "https://github.com/chaidiscovery/chai-lab/archive/refs/tags/v${CHAI_VERSION}.zip" \
    && unzip /tmp/chai.zip -d /tmp \
    && cp /home/rcsb.py /tmp/chai-lab-${CHAI_VERSION}/chai_lab/data/io/rcsb.py \
    && /root/.local/bin/uv pip install --no-cache-dir /tmp/chai-lab-${CHAI_VERSION}

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
COPY scripts /opt/scripts
COPY rcsb.py $VIRTUAL_ENV/lib/python3.11/site-packages/chai_lab/data/io/
WORKDIR /opt/scripts
RUN touch /opt/scripts/NO_MSA /opt/scripts/NO_TEMPLATE /opt/scripts/NO_PDB /opt/scripts/NO_CONSTRAINTS

# https://pytorch.org/docs/stable/notes/cuda.html#environment-variables
ENV PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

ENTRYPOINT []
