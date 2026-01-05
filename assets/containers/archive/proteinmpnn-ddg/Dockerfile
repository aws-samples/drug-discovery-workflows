FROM public.ecr.aws/ubuntu/ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl \
    git \
    wget \
    python3.10 \
    python3.10-venv \
    python3.10-dev \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

RUN python3.10 -m pip install --upgrade pip && \
    python3.10 -m pip install poetry

WORKDIR /app

RUN git clone https://github.com/PeptoneLtd/proteinmpnn_ddg.git && cd proteinmpnn_ddg && git checkout paper

COPY ./pyproject.toml /app/proteinmpnn_ddg/pyproject.toml
COPY ./poetry.lock /app/proteinmpnn_ddg/poetry.lock

WORKDIR /app/proteinmpnn_ddg

RUN poetry install -E cuda12 --no-root
