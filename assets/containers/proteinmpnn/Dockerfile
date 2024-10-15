ARG AWS_DEFAULT_REGION=us-east-1
FROM 763104351884.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/pytorch-inference:2.4.0-gpu-py311-cu124-ubuntu22.04-ec2

ARG COMMIT_SHA="8907e6671bfbfc92303b5f79c4b5e6ce47cdef57"

RUN apt-get update \
  && apt-get upgrade -y \
  && apt-get autoremove -y \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN wget -q -P /tmp "https://github.com/dauparas/ProteinMPNN/archive/${COMMIT_SHA}.zip" \
  && mkdir -p /opt/module \
  && unzip /tmp/${COMMIT_SHA}.zip -d /tmp \
  && mv /tmp/ProteinMPNN-${COMMIT_SHA}/* /opt/module

COPY requirements.txt /opt/module

# Install pip packages.
RUN pip3 install --upgrade pip --no-cache-dir \
  && pip3 install -r /opt/module/requirements.txt --no-cache-dir

WORKDIR /opt/module

ENTRYPOINT []