FROM nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04

# Fork includes fixes for import paths and missing dependencies
ARG RFANTIBODY_REPO=https://github.com/LevitateBio/RFantibody.git
ARG RFANTIBODY_VERSION=8aa519f81462461f3bd0c694a2c9b7086a112860

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y software-properties-common && \
    add-apt-repository -y ppa:deadsnakes/ppa && \
    apt-get install --no-install-recommends -y python3.10 python3-pip pipx vim make wget git tree

RUN alias "python"="python3.10"

# Make a virtual env that we can safely install into

RUN python3 -m venv /opt/venv
# Enable venv
ENV PATH="/opt/venv/bin:$PATH"

RUN pip install poetry


# Set the working directory to the user's home directory
WORKDIR /home


# RUN git clone https://github.com/RosettaCommons/RFantibody.git /home
RUN git clone ${RFANTIBODY_REPO} /home && git checkout ${RFANTIBODY_VERSION}

RUN chmod +x ./include/setup.sh && ./include/setup.sh

ENTRYPOINT /bin/bash
