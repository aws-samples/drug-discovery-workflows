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
  %% pip install -U pip \
  && pip install -q --no-cache-dir -r /home/requirements.txt \
  && pip install -q --no-cache-dir /home/putils \
  && yum autoremove -y \
  && yum clean all \
  && rm -rf /var/cache/yum

ENV VIRTUAL_ENV="/opt/venv"
ENV PATH="$VIRTUAL_ENV/bin:$PATH"
