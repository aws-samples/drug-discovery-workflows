ARG AWS_DEFAULT_REGION=us-east-1

FROM 763104351884.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/pytorch-inference:2.4.0-gpu-py311-cu124-ubuntu22.04-ec2

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install our own version of EvoProtGrad
COPY EvoProtGrad/ /home/EvoProtGrad/
WORKDIR /home/EvoProtGrad
RUN pip install -U --no-cache-dir .
RUN rm -rf /home/EvoProtGrad

# Install additional dependencies from requirements.txt file
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -U -r /tmp/requirements.txt \
    && rm /tmp/requirements.txt

## Cleanup ##
RUN pip cache purge \
    && rm -rf /tmp/tmp* \
    && rm -iRf /root/.cache

ENV TMPDIR="/tmp"
COPY scripts/ /home/scripts/
WORKDIR /home/scripts

ENTRYPOINT []