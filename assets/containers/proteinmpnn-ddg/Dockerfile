FROM public.ecr.aws/ubuntu/ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl \
    git \
    wget \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

RUN add-apt-repository ppa:deadsnakes/ppa && apt-get update && \
    apt-get install python3.10 python3.10-venv python3.10-dev python3.10-distutils -y

RUN curl -sS https://bootstrap.pypa.io/get-pip.py | python3.10

RUN pip install poetry

WORKDIR /app

RUN git clone https://github.com/PeptoneLtd/proteinmpnn_ddg.git && cd proteinmpnn_ddg && git checkout paper

COPY ./pyproject.toml /app/proteinmpnn_ddg/pyproject.toml
COPY ./poetry.lock /app/proteinmpnn_ddg/poetry.lock

WORKDIR /app/proteinmpnn_ddg

RUN poetry install -E cuda12 --no-root
