FROM public.ecr.aws/lambda/python:3.12

# Install python and other dependencies
COPY requirements.txt /tmp/requirements.txt
RUN dnf upgrade -y \
    && dnf install -y \
    unzip-6.0 \
    wget-1.21.3 \
    && python -m venv /opt/venv \
    && source /opt/venv/bin/activate \
    && pip install --no-cache-dir -r /tmp/requirements.txt \
    && dnf clean all \
    && rm -rf /var/cache/dnf \
    && rm -rf /tmp/putils \
    && rm /tmp/requirements.txt

ENV VIRTUAL_ENV="/opt/venv"
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

COPY scripts/ /home/scripts/
WORKDIR /home/scripts

ENTRYPOINT []