ARG AWS_DEFAULT_REGION=us-east-1

FROM 763104351884.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/pytorch-inference:2.4.0-gpu-py311-cu124-ubuntu22.04-ec2

# Install wget 
RUN apt-get update && \
    apt-get install -y wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Make environment and install dependencies
ADD environment.yml /tmp/environment.yml
RUN conda env create -n biophi -f /tmp/environment.yml

# activate environment
RUN echo "source activate biophi" > ~/.bashrc
ENV PATH=/opt/conda/envs/biophi/bin:$PATH