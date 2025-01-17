FROM ghcr.io/soedinglab/mmseqs2:master-cuda12 as mmseqs
# ARG COMMIT='acc0bf772f22feb7f887ad132b7313ff415c8a9f'

# RUN apt-get update \
# && apt-get upgrade -y \
# && apt-get install unzip -y \
# && apt-get autoremove -y \
# && apt-get clean \
# && rm -rf /var/lib/apt/lists/*

# RUN wget -q -P /tmp "https://github.com/sokrypton/ColabFold/archive/${COMMIT}.zip" \
#     && mkdir -p /opt/colabfold \
#     && unzip /tmp/${COMMIT}.zip -d /tmp \
#     && mv /tmp/ColabFold-${COMMIT}/* /opt/colabfold

RUN ln -s /usr/local/bin/entrypoint /usr/local/bin/mmseqs

WORKDIR /home

COPY setup_msa_databases.sh .

ENTRYPOINT []

# FROM mmseqs

# RUN apt-get update \
# && apt-get install git build-essential -y \
# && apt-get autoremove -y \
# && apt-get clean \
# && rm -rf /var/lib/apt/lists/*

# RUN wget -nc https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
# RUN bash Miniforge3-Linux-x86_64.sh -bfp /usr/local
# RUN rm -f Miniforge3-Linux-x86_64.sh
# # RUN CONDA_OVERRIDE_CUDA=$(echo $CUDA_VERSION | cut -d'.' -f1,2) mamba create -y -n colabfold -c conda-forge -c bioconda  jaxlib==*=cuda*
# RUN mamba create -y -n colabfold -c conda-forge -c bioconda
# RUN pip install -U "jax[cuda12]"
# RUN pip install -U git+https://github.com/sokrypton/ColabFold.git 
# RUN pip install "colabfold[alphafold]"
# RUN mamba clean -afy

# ENV PATH /usr/local/envs/colabfold/bin:$PATH
# ENV MPLBACKEND Agg

# VOLUME cache
# ENV MPLCONFIGDIR /cache
# ENV XDG_CACHE_HOME /cache