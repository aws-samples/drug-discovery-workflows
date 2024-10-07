<<<<<<< HEAD
FROM public.ecr.aws/amazonlinux/amazonlinux:2 as build

COPY code /tmp/putils

# Install python and other dependencies
RUN amazon-linux-extras install python3.8 \
  && yum upgrade -y \
  && yum install -y \
  unzip-6.0 \
  wget-1.14 \
  && python3.8 -m venv /opt/venv \
  && source /opt/venv/bin/activate \
  && pip install -q --no-cache-dir \
  pandas==2.0.0 \
  numpy==1.24.2 \
  biopython==1.81 \
  /tmp/putils \
  && yum clean all \
  && rm -rf /var/cache/yum \
  && rm -rf /tmp/putils
=======
FROM public.ecr.aws/amazonlinux/amazonlinux:2023 as build

WORKDIR /home

COPY code /home/putils
COPY requirements.txt /home

# Install python and other dependencies
RUN yum update \
  && yum upgrade -y \
  && yum install -y \
  python3.11 \
  unzip-6.0 \
  wget-1.21.3 \
  && python3.11 -m venv /opt/venv \
  && source /opt/venv/bin/activate \
  && pip install -U pip \
  && pip install -q --no-cache-dir -r /home/requirements.txt \
  && pip install -q --no-cache-dir /home/putils \
  && yum autoremove -y \
  && yum clean all \
  && rm -rf /var/cache/yum
>>>>>>> main

ENV VIRTUAL_ENV="/opt/venv"
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

<<<<<<< HEAD
WORKDIR /home
=======
ENTRYPOINT []
>>>>>>> main
