# https://gitlab.com/nvidia/container-images/cuda/-/tree/master/dist/12.6.3/amzn2023
FROM nvcr.io/nvidia/cuda:12.6.2-runtime-amzn2023 AS build
ARG UV_VERSION='0.5.13'
ARG PYTHON_VERSION='3.11'
ENV PATH="/opt/venv/bin:/root/.local/bin:$PATH" \
    UV_COMPILE_BYTECODE=1 \
    UV_PYTHON=python${PYTHON_VERSION} \    
    UV_PYTHON_DOWNLOADS=never

RUN dnf update -y \
    && dnf install -y nano tar gzip gcc python${PYTHON_VERSION} \
    && dnf clean all

WORKDIR /app

COPY requirements.txt requirements.txt
RUN curl -LsSf https://astral.sh/uv/${UV_VERSION}/install.sh | sh
RUN uv venv && uv pip install -r requirements.txt

############################################################################## Needs work
FROM nvcr.io/nvidia/cuda:12.6.2-runtime-amzn2023
ARG PYTHON_VERSION='3.11'

COPY --from=build /app /app

RUN dnf update -y \
    dnf install -y python${PYTHON_VERSION} \
    && dnf clean all

ENV PATH="/app/.venv/bin:$PATH"

ENTRYPOINT []