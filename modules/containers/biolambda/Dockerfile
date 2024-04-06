FROM public.ecr.aws/lambda/python:3.12

# Install python and other dependencies
RUN dnf upgrade -y \
    && dnf install -y \
    unzip-6.0 \
    wget-1.21.3 \
    && python -m venv /opt/venv \
    && source /opt/venv/bin/activate \
    && pip install --no-cache-dir \
    pandas==2.2.1 \
    numpy==1.26.4 \
    biopython==1.83 \
    pyfastx==2.1.0 \
    && dnf clean all \
    && rm -rf /var/cache/dnf \
    && rm -rf /tmp/putils

ENV VIRTUAL_ENV="/opt/venv"
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

COPY scripts/ /home/scripts/
WORKDIR /home/scripts

ENTRYPOINT [ "python" ]

