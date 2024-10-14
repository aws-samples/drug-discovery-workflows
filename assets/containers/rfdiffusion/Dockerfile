ARG AWS_DEFAULT_REGION=us-east-1
# FROM 763104351884.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/pytorch-inference:2.3.0-gpu-py311-cu121-ubuntu20.04-ec2
FROM 763104351884.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/pytorch-inference:2.4.0-gpu-py311-cu124-ubuntu22.04-ec2

ARG RFDIFFUSION_COMMIT="b44206a2a79f219bb1a649ea50603a284c225050"

RUN apt-get update \
  && apt-get upgrade -y \
  && apt-get autoremove -y \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN wget -q -P /tmp "https://github.com/RosettaCommons/RFdiffusion/archive/${RFDIFFUSION_COMMIT}.zip" \
  && mkdir -p /opt/module \
  && unzip /tmp/${RFDIFFUSION_COMMIT}.zip -d /tmp \
  && mv /tmp/RFdiffusion-${RFDIFFUSION_COMMIT}/* /opt/module

COPY requirements.txt /opt/module


# Install pip packages.
RUN pip3 install --upgrade pip --no-cache-dir \
  && pip3 install -r /opt/module/requirements.txt --no-cache-dir \
  && pip3 install dgl -f https://data.dgl.ai/wheels/torch-2.4/cu124/repo.html \
  && pip3 install /opt/module/env/SE3Transformer --no-cache-dir \
  && pip3 install /opt/module --no-cache-dir --no-deps --no-cache-dir

WORKDIR /opt/module

ENV DGLBACKEND="pytorch"

ENTRYPOINT []